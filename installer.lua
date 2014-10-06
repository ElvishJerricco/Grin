-- use build.xml to import the zip and json libraries directly

local zip = setmetatable({}, {__index=getfenv()})
local json = setmetatable({}, {__index=getfenv()})
local base64 = setmetatable({}, {__index=getfenv()})
local argparse = setmetatable({}, {__index=getfenv()})

do
    local function zip_api_make()
        @ZIP@
    end
    setfenv(zip_api_make, zip)
    zip_api_make()

    local function json_api_make()
        @JSON@
    end
    setfenv(json_api_make, json)
    json_api_make()

    local function base64_api_make()
        @BASE64@
    end
    setfenv(base64_api_make, base64)
    base64_api_make()

    local function argparse_api_make()
        @ARGPARSE@
    end
    setfenv(argparse_api_make, argparse)
    argparse_api_make()
end

local oldTime = os.time()
local function sleepCheckin()
    local newTime = os.time()
    if newTime - oldTime >= (0.020 * 1.5) then
        oldTime = newTime
        sleep(0)
    end
end

local function combine(path, ...)
    if not path then
        return ""
    end
    return fs.combine(path, combine(...))
end

-- Arguments

local parser = argparse.new()
parser
    :parameter"user"
    :shortcut"u"
parser
    :parameter"repo"
    :shortcut"r"
parser
    :parameter"tag"
    :shortcut"t"
parser
    :switch"emit-events"
    :shortcut"e"
parser
    :argument"dir"
parser
    :usage"Usage: grin -user <user> -repo <repo> [-tag tag_name] <dir>"
local options = parser:parse({}, ...)
if not options or not options.user or not options.repo or not options.dir then
    parser:printUsage()
    return
end

local print = print
if options["emit-events"] then
    function print(...)
        local s = ""
        for i,v in ipairs({...}) do
            s = s .. tostring(v)
        end
        os.queueEvent("grin_install_status", s)
    end
end


-- Begin installation

local githubApiResponse = assert(http.get("https://api.github.com/repos/"..options.user.."/"..options.repo.."/releases"))
assert(githubApiResponse.getResponseCode() == 200, "Failed github response")
print("Got github response")
local githubApiJSON = json.decode(githubApiResponse.readAll())

assert(type(githubApiJSON) == "table", "Malformed response")

local release
if options.tag then
    for i,v in ipairs(githubApiJSON) do
        if v.tag_name == options.tag then
            release = v
            break
        end
    end
    assert(release, "Release " .. options.tag .. " not found")
else
    release = assert(githubApiJSON[1], "Latest release not found")
end

local assetUrl = assert(release.assets and release.assets[1] and release.assets[1].url, "Malformed response")

print("Got JSON")
local zipResponse = assert(http.get(assetUrl, {["Accept"]="application/octet-stream"}))
assert(zipResponse.getResponseCode() == 200 or zipResponse.getResponseCode() == 302, "Failed zip response")
local base64Str = zipResponse.readAll()

print("Decoding base64")
sleep(0)
local zipTbl = assert(base64.decode(base64Str), "Failed to decode base 64")
print("Zip scanned. Unarchiving...")
sleep(0)

local i = 0
local zfs = zip.open({read=function()
    sleepCheckin()
    i = i + 1
    return zipTbl[i]
end})

local function copyFilesFromDir(dir)
    for i,v in ipairs(zfs.list(dir)) do
        sleepCheckin()
        local fullPath = fs.combine(dir, v)
        if zfs.isDir(fullPath) then
            copyFilesFromDir(fullPath)
        else
            print("Copying file: " .. fullPath)
            local fh = fs.open(combine(shell.resolve(options.dir), fullPath), "wb")
            local zfh = zfs.open(fullPath, "rb")
            for b in zfh.read do
                sleepCheckin()
                fh.write(b)
            end
            fh.close()
            zfh.close()
        end
    end
end

copyFilesFromDir("")
print("grin installation complete")
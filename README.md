Grin
====

Grin is a collection of libraries for ComputerCraft suited especially to download releases from github, encoded as .zip.base64 files.

To build the installer program, ant is required. This is because the libraries are consolidated into their related files, and need to be injected into installer.lua.

Usage
===

```
grin -user <user> -repo <repo> [-tag tag_name] <dir>
```

Shortcuts u, r, and t apply for user, repo, and tag respectively.
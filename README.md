# versionTools
Scripts I use to manage application versioning

The tools here are

## version.cmd

This is the main tool for generating version information from git, some of the ideas were taken from the tool GIT-VS-VERSION-GEN.bat

see: https://github.com/Thell/git-vs-versioninfo-gen/blob/master/GIT-VS-VERSION-GEN.bat

**Usage:** version [-h] | [-q] [-f] \[-a appid\] [*CACHE_PATH* *OUT_FILE*]

| Where      |                                                              |
| ---------- | ------------------------------------------------------------ |
| -h         | displays usage information                                   |
| -q         | suppresses console output                                    |
| -f         | ignores any cached version information                       |
| -a appid   | sets the appid tag to use. An appid of '.' uses the current directory name.<br />Note this overrides any GIT_APPID in the version.in file. |
| CACHE_PATH | a directory where an untracked cache info file is stored     |
| OUT_FILE   | path to a writeable file where the generated information is stored |

Example as a Visual Studio pre-build event:

call $(SolutionDir)..\tools\VERSION.cmd "$(IntDir)" "$(ProjectDir)version.h"

Note for Visual Sudio to get the event to trigger every time, add a dummy file to the additional dependencies.

For more information on the generated data and logic, see the VERSION.md file

## fileVer.cmd

This is a stripped down variant of version.cmd, that shows the revision of a particular file. This is useful where the version information generated by version.cmd cannot be readily consumed e.g. for a script file.

**Usage:** fileVer file

## install.cmd

This command is typically run post build to copy a built file to one or more locations.

**usage:** install file_with_path installRoot [configFile]

where configFile defaults to installRoot\install.cfg

 install.cfg contains lines of the form

srcDir,dir[,suffix]

Where

**srcDir** is the name compared with the  immediate parent directory name of file_with_path. If this matches the line is processed

**dir** is the name of directory to install to, with a leading + replaced by installRoot. 

**suffix** is inserted into the installed filename just before the .exe extension,  with a $d replaced by the local date in yyyymmdd format and $t replaced by the local time in hhmmss format

**Example** with install.cfg in the current directory containing the lines
x86-Release,+prebuilt
x86-Release,d:\bin,_32

install somepath\x86-Release\myfile.exe .
copies somepath\x86-Release\myfile.exe to .\prebuilt\myfile.exe and d:\bin\myfile_32.exe

A sample install.cfg can be found in repository

# release.cmd

This is primarily for my personal use. It creates a new tag to manage versions of individual applications in a repository. It also generates a default version info file which is committed to the repository. This is used by version.cmd on systems where git has not been installed.

Note there is a catch 22 scenario with respect to pre-built executables in that the build of the executable needs the version information including the git hash, generated by the release commit, so cannot be committed at the same time. The most sensible approach is to put any pre-built executables in a higher directory. Then once released a build can be done and the commit of the higher directory can be made, keeping the version information unchanged.

See VERSION.md for more details

There are two additional files I use in builds

## version.c

This contains a simple showVersion function which displays a brief version and copyright message. It also optionally displays additional information on the target build, Git Hash, commit date and whether the application was built with uncommitted files or outside git control all together.

## version.rc

A template file for a windows resource file for the file version information. The main customisation would be to the description.

If you use either of version.c or version.rc for your own projects, don't forget to change the copyright. 
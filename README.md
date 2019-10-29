# VSCL

VSCL-local.sh
-------------
The file "zzz SAMPLE VSCL-local.sh" conatins a template of the file "VSCL-local.sh" that should be created in a local .git to customize values for a particular EPO site.  The filename "VCSL-local.sh" is in .gitignore.  A *symlink* to it should be created in the "VSCL-Install" and "VSCL-Update-DAT" subdirectories.

To create a symlink in Windows, navigate to each directory where the symlink shoud be and run this command:
    `cmd /c mklink ./VSCL-local.sh ../VSCL-local.sh`

The main file VSCL-local.sh in the root and the symlinks required must be created manually PER ENDPOINT.

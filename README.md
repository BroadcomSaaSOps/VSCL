# McAfee VirusScan Command Line scripts for deployment from McAfee EPO to support the command-line scanner functionality of PPM

## Purpose
The McAfee VirusScan Command Line (VSCL) tool is not natively supported as an ePolicy Orchestrator (EPO) managed software package.  This set of scripts is used in combination with the free community EPO Enterprise Deployment Kit (EEDK) tool to create EPO-compatible packages that can be deployed manually to mimic the function of supported EPO packages.

EPO is deployed in several datacenters globally which are managed by Broadcom SaaS Ops:
- AU1  (Sydney, Australia)
- DEMUN  (Munich, Germany)
- SC5  (San Diego, CA, USA)
- SaaS FedRAMP Environment in Azure, aka FedRAMP

## Workflow

### Preparatory steps performed once for each Datacenter
1. Install the Git command line tool (https://git-scm.com/downloads) or Github Desktop (https://desktop.github.com/) to the McAfee EPO server.
2. Clone [this repository](https://github.com/tayni03/VSCL).
3. Create the file `<root/>VSCL-local.sh` MANUALLY in the local repository and symlink it into the appropriate subdirectories (directions below).
4. Create a symlink in the `VSC:-Install` directory to  `<root>/VSCL-Update-DAT/VSCL-Update-DAT.sh`.
5. Set up the EEDK executable (a copy is provided in the `EEDK` subdirectory of the repository)

### After modifying script(s) for any of the VSCL packages:
1. Verify that the repository is synced with the master repository.
2. Start up EEDK and load in the appropriate `.EEDK` file for the package from `<root>`.
3. Update the version number if required.
4. Create the output EPO package to a local `builds` directory
5a. Upload the new package to the EPO server (this step will *NOT* work in FedRAMP!)
5b. Log into EPO and manually import the new package to the Master Repository (FedRAMP only!)
6. From the EPO system tree, the package will be available to select from deployable packages for one or more clients.

## File and Package details

### Package: `VSCL-Install`  (VSCLINST)
#### Purpose:
Performs a fresh install of VSCL on a PPM client system.
#### Imports:
- `VSCL-local.sh` (symlink to root of local repository)
- `update-uvscan-dat.sh` (this directory)
- `VSCL-Update-DAT.sh` (from `VSCL-Update-DAT` directory)
#### External Requirements:
- Custom `VSCL-Package` package installed into EPO (this is a central copy of the VSCL client install).
- McAfee VirusScan Enterprise scanner installed into EPO (this is where daily `.DAT` files are pulled from).
    *PLEASE NOTE*: The VSE package is required even if VSE is not used in the enviroment.
#### Usage:
Standard client package deployment via EPO.

### Package: `VSCL-Update-DAT`  (VSCLUP1)
#### Purpose:
Updates an EPO client using VSCL with the newest DAT files downloaded from McAfee.  This should be run on all clients at least daily via a client task scheduled in EPO.
#### Imports:
- `VSCL-local.sh` (symlink to root of local repository)
#### External Requirements:
- Mcafee VirusScan Enterprise scanner installed into EPO (this is where daily `.DAT` files are pulled from).
    *PLEASE NOTE*: The VSE package is required even if VSE is not used in the enviroment.
#### Usage:
Standard client package deployment via EPO.

### Package: `VSCL-Update-Prop1`  (VSCLUP1)

### Package: `VSCL-Uninstall`  (VSCLUNIN)

### File: `VSCL-local.sh`
#### Purpose:
Contains per-site custom values for other VSCL scripts.
#### Imports:
None
#### External Requirements:
None
#### Usage:
The file `zzz SAMPLE VSCL-local.sh` contains a template of the file `VSCL-local.sh` that should be created in the local repository.  The filename `VCSL-local.sh` is in .gitignore.  A *symlink* to it should be created in the `VSCL-Install` and `VSCL-Update-DAT` subdirectories.

To create a symlink in Windows, navigate to each directory where the symlink shoud be and run this command:
    `cmd /c mklink ./VSCL-local.sh ../VSCL-local.sh`

The main file VSCL-local.sh in the root and the symlinks required must be created manually PER ENDPOINT.

Modify the contents per this example:
```
    # site identifier
    SITE_NAME="AU1"

    # McAfee repo server
    EPO_SERVER="MCAFEE01"`
```
Together $SITE_NAME+$EPO_SERVER will equal the name of the local EPO server,
e.g. "AU1" + "MCAFEE01" = "AU1MCAFEE01" for Australia, or "AVAN" + "MAV001" = "AVANMAV001" for FedRAMP

## NOTES
1. Each site repository should have the entry...
```
    [core]
        autocrlf = input
```
  placed in the `<root>/.git/config` file. This will maintain line endings to whatever is originally loaded into the master repository.  EPO scripts packaged by EEDK for deployment to Linux endpoints require Unix-style `LF` line endings.  Windows endpoints use `CRLF` endings.  Make sure that the text editor used to modify scripts honors this convention and saves files with the appropriate endings.  Git will not alter them.

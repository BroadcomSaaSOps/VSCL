# McAfee VirusScan Command Line scripts for deployment from McAfee EPO to support antivirus scanning of customer files upoaded to PPM

## Purpose
The McAfee VirusScan Command Line (VSCL) tool is required for the correct functioning of the PPM application hosted by Broadcom SaaS. Unfortunately, while it is a member of the McAfee suite of tools, is not natively supported as an ePolicy Orchestrator (EPO) managed software package.  This set of scripts is used in combination with the free community EPO Enterprise Deployment Kit (EEDK) tool to create EPO-compatible packages.  These packages can be deployed manually to mimic the remote installation and management functionality of packages designed to work with EPO.

EPO is deployed independently to several "sites" in On-Premise mode.  Each site is a global datacenter managed by Broadcom SaaS Ops and is referenced by a site code:
- AU1  (Sydney, Australia)
- DEMUN  (Munich, Germany)
- SC5  (San Diego, CA, USA)
- SaaS FedRAMP Environment in Azure, aka FedRAMP

## Workflow

### Preparatory steps performed ONLY ONCE for each site:
1. Install the [Git command line tool for Windows](https://git-scm.com/downloads) and [Github Desktop for Windows](https://desktop.github.com/) on the site's McAfee EPO server.
2. Clone this [Git repo](https://github.com/BroadcomSaaSOps/VSCL.git) to a directory on the site's EPO server.  By default, the directory is `E:\Software\McAfee\EEDK\Development\VSCL`, but it may vary per site.
3. In the local Git repo, MANUALLY create symlinks as follows (directions for creating symlinks below):
   a. `/VSCL-local.sh` in the `VSCL-Install` directory
   b. `/VSCL-Update-DAT/VSCL-Update-DAT.sh`, in the `VSCL-Install` directory
   c. `/VSCL-local.sh` in the `VSCL-Install` directory
4. Set up the EEDK executable on the EPO server.  Under the properties for the executable, configure it to always "Run as Administrator" for all users under "Compatibility Options".
    *PLEASE NOTE*: A copy of EEDK v9.6.1 is provided in the `EEDK` subdirectory of the Git repo.  It is also available for download from McAfee [here](https://nofile.io/f/AqKytH7Fp86/ePO.Endpoint.Deployment.Kit.9.6.1.zip).  It is *highly recommended* that the EEDK executable be copied to and run from a directory OUTSIDE the local Git repo.
5. Make sure that the latest 64-bit version of the VSCL package has been uploaded to EPO:
   a. Check that the "VSCL-Package" in the EPO "Master Repository" is the latest available from [McAfee Product Downloads](https://www.mcafee.com/content/enterprise/en-us/downloads/my-products/downloads.html).
   b. If not, the file `vscl-l64-<version#>-l.tar.gz` should be downloaded and copied to the local Git repo's `/VSCL-Package` directory.  Any old versions should be deleted.
   c. Update the "FILENAME" entry in the "[VSCL-PACK]" section of the `/VSCL-Package/vsclpackage.ini` file in the same directory to match.
   d. Remove any old versions of "VSCL-Package" from the EPO "Master Repository".
   e. Resync the Git repo to distribute this new version of VSCL to all sites.
   f. For each site, resync the Git repo and repeat the above steps to create the new package and import it to EPO.

### After modifying script(s) for any of the custom VSCL packages in any site:
1. Verify that any changes made to the local Git repo are synced with the GitHub repository.
2. Start up EEDK and load in the appropriate `.EEDK` file for the package. NOTE: These are in the root of the Git repo.
3. Update the version number displayed in EEDK, if required.
4. Create the new version of EPO package to a local `builds` directory.  The filename will be `<package><version>.ZIP` (eg. "VSCLPACK6130.zip").
5. Save the updated `.EEDK` file over the original one.  NOTE: `.EEDK` files should NOT have a version number in the name.
5. Import the new version of the package to the EPO server's "Master Repository":
   a. For *non-FedRAMP* sites, you can directly from the EEDK tool to EPO.
   b. Otherwise, log into EPO and manually import the new package to the "Master Repository".  NOTE: Manual upload is only required for the FedRAMP site.
6. From the EPO system tree, the package will be available to select as a deployable package for one or more clients.
7. Delete any old versions of the package from EPO's "Master Repository".
8. Perform the above steps on all remaining sites.

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
    *PLEASE NOTE*: The VSE package is required to be available in EPO even if VSE is not used in the enviroment.
#### Usage:
Standard client package deployment via EPO.

### Package: `VSCL-Update-DAT`  (VSCLUDAT)
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
The file `zzz SAMPLE VSCL-local.sh` contains a template of the file `VSCL-local.sh` that should be created in the local repository for a particular site.  The filename `VCSL-local.sh` is in .gitignore.  A *symlink* to it should be created in the `VSCL-Install` and `VSCL-Update-DAT` subdirectories.

To create a symlink in Windows, navigate to each directory where the symlink shoud be and run this command:
    `cmd /c mklink ./VSCL-local.sh ../VSCL-local.sh`

*PLEASE NOTE*: The main file `VSCL-local.sh` is in the root of the repository. The symlinks required must be created manually PER SITE.

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

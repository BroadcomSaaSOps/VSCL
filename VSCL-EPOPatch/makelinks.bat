cd E:\Software\McAfee\EEDK\Development\VSCL\VSCL-EPOPatch
del .\VSCL-Update-Prop1.sh
del .\VSCL-Update-DAT.sh
del .\VSCL-lib.sh
del .\VSCL-local.sh
cmd /c mklink .\VSCL-local.sh E:\Software\McAfee\EEDK\Development\VSCL\VSCL-local.sh
cmd /c mklink .\VSCL-lib.sh E:\Software\McAfee\EEDK\Development\VSCL\VSCL-Common\VSCL-lib.sh
cmd /c mklink .\VSCL-Update-DAT.sh E:\Software\McAfee\EEDK\Development\VSCL\VSCL-Update-DAT\VSCL-Update-DAT.sh
cmd /c mklink .\VSCL-Update-Prop1.sh E:\Software\McAfee\EEDK\Development\VSCL\VSCL-Update-Prop1\VSCL-Update-Prop1.sh

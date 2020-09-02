cd E:\Software\McAfee\EEDK\Development\VSCL\VSCL-Update-Prop1
del .\VSCL-lib.sh
del .\VSCL-local.sh
cmd /c mklink .\VSCL-local.sh E:\Software\McAfee\EEDK\Development\VSCL\VSCL-local.sh
cmd /c mklink .\VSCL-lib.sh E:\Software\McAfee\EEDK\Development\VSCL\VSCL-Common\VSCL-lib.sh

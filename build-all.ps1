# variables
$buildDir = "E:\Software\McAfee\EEDK\Builds"
$EEDKExe = "E:\Software\McAfee\EEDK\EEDK.exe"
$sourceDir = "E:\Software\McAfee\EEDK\Development\VSCL"
$EPOServer="avanmav001.casaasops.az.com"
$uploadPort=8443
$uploadPath="remote/repository.checkInPackage"
$uploadParams="branch=Current&option=Normal&force=true&allowUnsignedPackages=true"

Set-Location -Path $sourceDir

# delete old builds
Remove-Item -Path "$buildDir\VSCL*.*" -Force

# rebuild .EEDKs
$buildOutput = @()
$EEDKList = Get-ChildItem -Path ".\VSCL-*.eedk"

foreach ($EEDKFile in $EEDKList) {
    "Running EEDK for '$EEDKfile'..."
    $capture = @(& $EEDKExe -Settings:"$EEDKFile")
    $buildOutput += ,$capture
    "Result: '$($capture[-1])'"
}

$ZIPList = $buildOutput | % { (($_ | sls "^Zipping Package") -split " ")[2] }

# fix upload parameters in powershell's network connection
Add-Type -TypeDefinition @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate,WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# get user credentials for upload
$cred = Get-Credential
$uploadOutput = @()

# upload built .ZIP files
foreach ( $ZIPFile in $ZIPList ) {
    "Uploading '$ZIPfile'..."
    $uploadURI = "https://${EPOServer}:${uploadPort}/${uploadPath}?packageLocation=${ZIPFile}&${uploadParams}"
    $capture=Invoke-WebRequest -Uri $uploadURI -Credential $cred
    $uploadOutput += ,$capture
    "Result: '$($capture.StatusDescription)'"
}
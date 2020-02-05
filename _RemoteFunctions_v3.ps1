[CmdletBinding()]
Param ()

<#	
	.NOTES
	===========================================================================
	 Created on:   	12/10/2017
	 Created by:   	 tayni03
	 Organization: 	CA SaaS Ops
	 Filename:     	_RemoteFunctions_v3.ps1
	===========================================================================
	.DESCRIPTION
		Library of functions for remotely accessing systems via Powershell Remoting
#>

#----------------------------------------------------------
# GLOBALS
#----------------------------------------------------------

# Turn off all hard errors and continue quietly
$saveErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

# log file
$systemRoot = Join-Path -Path $env:SystemDrive -ChildPath "\"
$thisScript = "_RemoteFunctions_v3"

#Write-Output "`$global:logFile = '$($global:logFile)'"

if (! $global:logFile) {
	$global:logFile = "$PSScriptRoot\$thisScript.LOG"
	#Write-Output "`$global:logFile = '$($global:logFile)'"
}

# GUID for tracking remote jobs
$global:invokeJobGUID = "bb606ee8-210f-4338-98e0-e1ffa1ac2565"

if ($env:USERDNSDOMAIN) {
	# Get current domain from current user environment
	$currentDomain = $env:USERDNSDOMAIN.ToUpper()
} else {
	# SYSTEM account has no domain, so figure it out from machine FQDN
	$currentHost = $env:COMPUTERNAME.ToUpper()
	$currentFQDN = [System.Net.Dns]::GetHostByName($currentHost).HostName.ToUpper()
	$currentDomain = $currentFQDN.Replace("${currentHost}.", "")
}

$domainDir = "\\$currentDomain\NETLOGON"

# List of modules to import if needed
$requiredModules = "PSWindowsUpdate", "TaskScheduler"

#----------------------------------------------------------------------------------------
# FUNCTIONS
#----------------------------------------------------------------------------------------

function Call-NativeCommand {
	[CmdletBinding()]
	Param (
		[Parameter()]
		[string[]]$commandToRun,
		
		[Parameter()]
		[switch]$debugIt
	)
	
	$commandToRun = $commandToRun -join " "
	$commandToRun += " 2>&1"
	$result = Invoke-Expression -Command "$commandToRun" -ErrorAction SilentlyContinue
	$result | ForEach-Object{
		$e = ""
		
		if ($_.WriteErrorStream) {
			$e += $_
		} else {
			$_
		}
		Write-Log -Message $e
	}
}

#----------------------------------------------------------------------------------------

Function Load-PSModule {
	<#
		.SYNOPSIS
			Load a required list of Powershell Modules
	
		.DESCRIPTION
			A detailed description of the function.
	
		.PARAMETER  ModuleName
			List of one or more Powershell module names to load
	
		.EXAMPLE
			Load-PSModule -ModuleName "PSWindowsUpdate"
	
		.EXAMPLE
			"PSWindowsUpdate", "TaskScheduler" | Load-PSModule
	
		.INPUTS
			string[]
	
		.OUTPUTS
			None
	
		.NOTES
			If module is not available locally, the function will attempt to copy it from 
			the \\<domain>\NETLOGON directory and register it locally with Powershell
	#>
	
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   Position = 0)]
		[string[]]$ModuleName
	)
	
	Begin { }
	
	Process {
		$modName = $ModuleName[0]
		
		if (-not (Get-Module -Name $modName -ListAvailable -ErrorAction SilentlyContinue)) {
			Write-Log -Message "Cannot locate loadable local copy of module '$modName'!"
			# Copy module from network to local and import
			$newModuleDir = "$PSHome\Modules\$modName\"
			Write-Log -Message "Creating local module directory '$newModuleDir'..."
			New-Item -ItemType Directory -Force -Path $newModuleDir -Verbose | Write-Log
			$netModuleFiles = "\\$currentDomain\NETLOGON\$modName\*"
			Write-Log -Message "Copying module from network..."
			Copy-Item -Force -Path $netModuleFiles -Destination $newModuleDir -Verbose | Write-Log
		}
		
		Import-Module $modName | Write-Log
	}
	
	End { }
}

#----------------------------------------------------------------------------------------

Function Convert-HashToObject () {
	#=================================================
	# 
	# 
	#=================================================
<#
	Purpose:	Takes a hashtable and creates a new custom psobject from it
	Inputs:		$hashToConvert:	hashtable with structure of new object
	Output:		new custom object
	Example:	Convert-HashToObject @{"a"="hello"; "b"="goodbye"}
				Returns object with typedef:
				
					TypeName: System.Management.Automation.PSCustomObject

					Name           MemberType   Definition
					----           ----------   ----------
					Equals         Method       bool Equals(System.Object obj)
					GetHashCode    Method       int GetHashCode()
					GetType        Method       type GetType()
					ToString       Method       string ToString()
					a              NoteProperty System.String a=hello
					b              NoteProperty System.String b=goodbye
					PSComputerName NoteProperty  PSComputerName=null
#>
	
	[CmdletBinding()]
	[OutputType([psobject])]
	Param (
		[Parameter(
				   Mandatory = $True,
				   ValueFromPipeline = $True)]
		[ValidateNotNullOrEmpty()]
		[psobject]$hashToConvert
	) # end Param
	
	Begin { }
	
	Process {
		if ($hashToConvert -isnot [hashtable]) {
			return ""
		}
		
		if (-not ($hashToConvert.Keys -icontains "PSComputerName")) {
			$hashToConvert.Add("PSComputerName", $hashToConvert.PSComputerName)
		}
		
		$newObject = New-Object -TypeName psobject -Property $hashToConvert
		return [psobject]$newObject
	}
	
	End { }
} # end function

#----------------------------------------------------------------------------------------

Function Write-Log {
	#===========================================================================
	# This function writes formatted messages to a log file with timedate stamps
	#===========================================================================
	[CmdletBinding(DefaultParameterSetName = "messageSet")]
	Param (
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   Position = 0,
				   ParameterSetName = "messageSet")]
		[psobject]$Message,
		
		[Parameter(Mandatory = $true,
				   Position = 0,
				   ParameterSetName = "newSet")]
		[switch]$beginNewLog = $false
	)
	
	Begin {
		Function Get-LogStamp {
			#returns a padded timestamp string like 200705231132
			$now = Get-Date
			$yr = $now.Year.ToString()
			$mo = $now.Month.ToString()
			$dy = $now.Day.ToString()
			$hr = $now.Hour.ToString()
			$mi = $now.Minute.ToString()
			
			if ($mo.length -lt 2) {
				$mo = "0" + $mo #pad single digit months with leading zero
			}
			
			if ($dy.length -lt 2) {
				$dy = "0" + $dy #pad single digit day with leading zero
			}
			
			if ($hr.length -lt 2) {
				$hr = "0" + $hr #pad single digit hour with leading zero
			}
			
			if ($mi.length -lt 2) {
				$mi = "0" + $mi #pad single digit minute with leading zero
			}
			
			"$yr$mo$dy$hr$mi"
		}
	}
	
	Process {
		if ($PSCmdlet.ParameterSetName -eq "messageSet") {
			$OutputText = $Message

			# Output computername if available
			if ($OutputText.PSComputerName) { 
				#$OutputText = "$OutputText : Has computername!"
				$OutputText = "$($OutputText.PSComputerName): $OutputText"
			}

			# Add timestamp
			$OutputText = "$(Get-LogStamp): $OutputText"
			
			if ($global:logfile) {
				# Logging to a file
				try {
					#Add-Content $logFile -Force -Value $Output -Encoding Ascii
					$OutputText | Out-File -FilePath $global:logFile -Force -Append -Encoding Ascii
				} catch {
					Write-Output "ERROR >>> $($_.Exception.Message)"
				}
			}
			
			# Log to verbose output
			if (($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) -or ($VerbosePreference -ne 'SilentlyContinue')) {
				Write-Verbose $OutputText
			}
		} else {
			$OutputText = @"

#----------------------------------------------------------------------------------------
#  NEW LOG RUN - $(Get-LogStamp)
#----------------------------------------------------------------------------------------
"@
			$OutputText | Out-File -FilePath $global:logFile -Force -Append -Encoding Ascii
		}
	}
	
	End { }
}

#----------------------------------------------------------------------------------------

Function Get-SysNamesFromText {
	#===========================================================================
	# Takes an input string or string[] of system names and creates 
	# an object containing the name(s) with the current user's credential embedded
	#===========================================================================
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $false)]
		[string[]]$ComputerName,
		
		[Parameter(Mandatory = $false)]
		[Alias('RunAs', 'Credential', 'Cred', 'Creds')]
		[pscredential]$defaultCredential = [pscredential]::Empty,
		
		[Parameter()]
		[string[]]$limitTo = @(""),
		
		[Parameter()]
		[string[]]$exclude = @("")
	)
	
	Begin { }
	
	Process {
		$sysNameCol = "SystemName"
		$usernameCol = "UserName"
		$passwordCol = "Password"

		if ($defaultCredential -eq [pscredential]::Empty) {
			$convertFilter = @{ Name = ($sysNameCol); Expression = { ($_).Trim() } }, @{ Name = "credential"; Expression = { Get-UserCredential } }
		} else {
			$convertFilter = @{ Name = ($sysNameCol); Expression = { ($_).Trim() } }, @{ Name = "credential"; Expression = { $defaultCredential } }
		}
		
		$Names = $ComputerName | Select-Object -Property $convertFilter
		
		if ($limitTo) {
			$Names = $Names | Where-Object { $_.SystemName -in $limitTo }
		}
			
		if ($exclude) {
			$Names = $Names | Where-Object { -not ( $_.SystemName -in $exclude ) }
		}
		
		$Names
	}
	
	End { }
}

#----------------------------------------------------------------------------------------

Function Get-SysNamesFromFile {
	#===========================================================================
	# Takes an input text file of system names in .CSV format and returns an array
	# the system name(s) with the credential from the file (if supplied) or 
	# the current user's credential embedded
	#
	# NOTE: .CSV file MUST have at least one header line of "SystemName"
	#       -OR-
	#       "SystemName","UserName","Password"
	#===========================================================================
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[Alias('File', 'Path')]
		[System.IO.FileInfo]$nameFile,
		
		[Parameter(Mandatory = $false)]
		[Alias('RunAs', 'Credential', 'Cred', 'Creds')]
		[pscredential]$defaultCredential = [pscredential]::Empty,
		
		[Parameter()]
		[switch]$debugIt,
		
		[Parameter()]
		[string[]]$limitTo = @(""),
		
		[Parameter()]
		[string[]]$exclude = @("")
	)
	
	$sysNameCol = "SystemName"
	$userNameCol = "UserName"
	$passwordCol = "Password"
	
	# passing in server names by file
	$Names = @()
	$ComputerName = @()
	#massage path to be relative to script directory
	if ($debugIt) { "`$nameFile = '$nameFile'" }
	$nameFile = Convert-Path $nameFile
	
	# Pull in list of server names from file
	if (-not $nameFile) {
		# File missing
		Write-Log -Message "ERROR > Invalid or empty server list file '$($nameFile.Fullname)'!"
		return $null
	} else {
		if ($debugIt) { Write-Log -Message "DEBUG > File '$($namefile.Fullname)' exists!" }
		# import CSV of servernames with at least one column named "SystemName"
		$Names = Import-Csv $namefile -ErrorAction SilentlyContinue
		
		if ($Names) {
			#strip CSV format to array of names
			$Names = $Names | Where-Object ($sysnameCol) -NotMatch '^#.*$'
			
			if ($defaultCredential -ne [pscredential]::Empty) {
				# Massage each line to have default credential supplied
				$convertFilter =
				@{ Name = $sysNameCol; Expression = { ($_.$sysNameCol).Trim() } },
				@{ Name = "credential"; Expression = { $defaultCredential } }
			} else {
				# Massage each line to have credential supplied from file or current user
				$convertFilter =
				@{ Name = $sysNameCol; Expression = { ($_.$sysNameCol).Trim() } },
				@{
					Name = "credential";
					Expression = {
						if ($_.Username) { New-UserCredential -userName (($_.$usernameCol).Trim()) -Password (($_.$passwordCol).Trim()) } else { Get-UserCredential }
					}
				}
			}
			
			$ComputerName = @($Names | Select-Object -Property $convertFilter)

			if ($limitTo) {
				$ComputerName = $ComputerName | ? { $_.SystemName -in $limitTo }
			}
			
			if ($exclude) {
				$ComputerName = $ComputerName | Where-Object { -not ($_.SystemName -in $exclude ) }
			}
		}
	}
	
	#if ($debugIt) { "`$ComputerName = '$($ComputerName.Count)'" }
	
	$ComputerName
}

#----------------------------------------------------------------------------------------

Function Open-ServerSessions {
	[CmdletBinding()]
	Param (
		[string[]]$ComputerName,
		
		[pscredential]$Credential,
		
		[Parameter()]
		[switch]$noDoubleHop = $false
	)
	
	Begin {
		$goodSessions = @{ }
		$tryResetSessions = @{ }
		$errorSessions = @{ }
		$warningSessions = @{ }
	} # end begin block
	
	Process {
		#region STAGE 1: Check for network connectivity
		Write-Log -Message "STAGE 1: Check for network connectivity..."
		$num = $ComputerName.Count
		$curr = 1
		
		# First pass, check for ping
		foreach ($sysName in $ComputerName) {
			Write-Progress -Activity "STAGE 1: Check for network connectivity..." -PercentComplete ([int](($curr++ / $num) * 100)) -Status $sysName
			Write-Log "Checking for network connectivity to '${sysName}'..."
			
			If (Test-Connection -ComputerName $sysName -Count 1 -Quiet) {
				Write-Log -Message "SUCCESS: System '${sysName}' is reachable over the network!"
				$goodSessions.Add($sysName, $null)
			} else {
				$errorSessions.Add($sysName, "ERROR > System '${sysName}' is unreachable over the network!")
			}
		}
		
		Write-Progress -Activity "STAGE 1: Check for network connectivity..." -Completed
		#endregion 
		
		# $goodSessions: ONLY network-reachable (pingable) systems
		# $errorSessions: network-unreachable (pingable) systems
		
		# check if initial PSRemote connection can be established...
		
		#region STAGE 2: Check for initial PSRemote connection
		Write-Log -Message "STAGE 2: Check for initial PSRemote connection..."
		$num = $goodSessions.Count
		$curr = 1
		
		foreach ($sysName in @($goodSessions.Keys)) {
			Write-Progress -Activity "STAGE 2: Check for initial PSRemote connection..." -PercentComplete ([int](($curr++ / $num) * 100)) -Status $sysName
			Write-Log -Message "Connecting with PSRemoting to '${sysName}'..."
			
			$newSession = $null
			$sessOpts = New-PSSessionOption -NoMachineProfile -OpenTimeout 5000 -CancelTimeout 5000 -IdleTimeout 60000 -OperationTimeout 60000
			$newSession = New-PSSession -ComputerName $sysName -EnableNetworkAccess -Credential $Credential -Authentication Credssp -ErrorAction SilentlyContinue -SessionOption $sessOpts
			
			if ($newSession) {
				Write-Log -Message "SUCCESS: Opened initial PSRemote connection to '${sysName}'!"
				$goodSessions.$sysName = $newSession
			} else {
				Write-Log -Message "WARNING > Could not open initial PSRemote connection to '${sysName}', attempting reset of CredSSP!"
				$goodSessions.Remove($sysName)
				$tryResetSessions.Add($sysName, $null)
			}
		}
		
		Write-Progress -Activity "STAGE 2: Check for initial PSRemote connection..." -Completed
		#endregion 
		
		# $goodSessions: systems that have passed all tests so far
		# $errorSessions: network-unreachable systems
		# $tryResetSessions: systems that failed initial PSRemote connection
		
		# for any systems in $tryResetSessions, try resetting CredSSP with PSExec
		
		#region STAGE 2a: Reset CredSSP on systems that failed initial PSRemote connection
		if ($tryResetSessions.Count) {
			Write-Log -Message "STAGE 2a: Reset CredSSP on systems that failed initial PSRemote connection..."
			$num = $tryResetSessions.Count
			$curr = 1
			
			foreach ($sysName in @($tryResetSessions.Keys)) {
				Write-Progress -Activity "STAGE 2a: Reset CredSSP on systems that failed initial PSRemote connection..." -PercentComplete ([int](($curr++ / $num) * 100)) -Status $sysName
				
				# Cannot access server with CredSSP, try to use PSExec to enable CredSSP access and retry
				$resetWorked = Setup-CredSSP -setupName $sysName -setupcredential $Credential
				
				if (-not $resetWorked) {
					# CredSSP reset failed
					$goodSessions.Remove($sysName)
					$tryResetSessions.Remove($sysName)
					$errorSessions.Add($sysName, "ERROR > Error resetting CredSSP on '$sysName'!")
				} #end if
			} #end for
		} #end if
		
		Write-Progress -Activity "STAGE 2a: Reset CredSSP on systems that failed initial PSRemote connection..." -Completed
		#endregion 
		
		# $goodSessions: systems that have passed all tests so far
		# $errorSessions: unreachable systems or failed CredSSP reset
		# $tryResetSessions: systems that failed initial PSRemote connection and had CredSSP successfully reset
		
		# for any systems in $tryResetSessions, retry initial PSRemote connection
		
		#region STAGE 2b: Recheck systems that had CredSSP reset for initial PSRemote connection
		if ($tryResetSessions.Count) {
			Write-Log -Message "STAGE 2b: Recheck systems that had CredSSP reset for initial PSRemote connection..."
			$num = $tryResetSessions.Count
			$curr = 1
			
			foreach ($sysName in @($tryResetSessions.Keys)) {
				# CredSSP reset successfully, retry initial PSRemote connection
				Write-Progress -Activity "STAGE 2b: Recheck systems that had CredSSP reset for initial PSRemote connection..." -PercentComplete ([int](($curr++ / $num) * 100)) -Status $sysName
				Write-Log -Message "Connecting with PSRemoting to '${sysName}'..."
				
				$newSession = $null
				$sessOpts = New-PSSessionOption -NoMachineProfile -OpenTimeout 5000 -CancelTimeout 5000 -IdleTimeout 60000 -OperationTimeout 60000
				$newSession = New-PSSession -ComputerName $sysName -EnableNetworkAccess -Credential $Credential -Authentication Credssp -ErrorAction SilentlyContinue -SessionOption $sessOpts
				
				if ($newSession) {
					# PSRemoting worked after CredSSP reset
					Write-Log -Message "SUCCESS: After resetting CredSSP, successfully opened initial PSRemote connection to '${sysName}'!"
					$warningSessions.Add($sysName, "WARNING > After resetting CredSSP, successfully opened initial PSRemote connection to '$sysName'!")
					$goodSessions.Add($sysName, $newSession)
				} else {
					# PSRemoting failed after CredSSP reset
					Write-Log -Message "ERROR > After resetting CredSSP, could not open initial PSRemote connection on '${sysName}'!"
					$errorSessions.Add($sysName, "ERROR > After resetting CredSSP, could not open initial PSRemote connection on '$sysName'!")
				} # end if
			} #end for
		} #end if
		
		$tryResetSessions.Clear()
		Write-Progress -Activity "STAGE 2b: Recheck systems that had CredSSP reset for initial PSRemote connection..." -Completed
		#endregion 
		
		# $goodSessions: systems that have passed all tests so far
		# $warningSessions: systems that required CredSSP reset
		# $errorSessions: unreachable, failed CredSSP reset, or failed initial PSRemote connection after CredSSP reset
		# $tryResetSessions: cleared
		
		# check for network double-hop access (i.e. remote session can access resources on the network)
		
		# create scriptblock for network double-hop access testing
		$testScriptBody = "dir \\$($env:userdomain)\sysvol"
		$testScript = [scriptblock]::Create($testScriptBody)
		
		if (-not $noDoubleHop) {
			#region STAGE 3: Check for network double-hop access
			Write-Log -Message "STAGE 3: Check for network double-hop access..."
			
			$num = $goodSessions.Count
			$curr = 1
			
			foreach ($sysName in @($goodSessions.Keys)) {
				Write-Progress -Activity "STAGE 3: Check for network double-hop access..." -PercentComplete ([int](($curr++ / $num) * 100)) -Status $sysName
				Write-Log -Message "Testing network double-hop access for '${sysName}'..."
				
				$testResult = $null
				$testResult = Invoke-Command -Session $goodSessions.$sysName -ScriptBlock $testScript -ErrorAction SilentlyContinue
				
				# make sure the TypeNames collection exists before checking its contents!
				if ($testResult -and
					$testResult.psobject -and
					$testResult.psobject.TypeNames -and
					$testResult.psobject.TypeNames -icontains "Deserialized.System.IO.DirectoryInfo") {
					Write-Log -Message "SUCCESS: Verified network double-hop access from '${sysName}'!"
				} else {
					Write-Log -Message "WARNING > Could not verify network double-hop access, attempting reset of CredSSP on '${sysName}'!"
					$goodSessions.Remove($sysName)
					$tryResetSessions.Add($sysName, $null)
				}
			}
			
			Write-Progress -Activity "STAGE 3: Check for network double-hop access..." -Completed
			#endregion 
			
			# $goodSessions: systems that have passed all tests so far
			# $warningSessions: systems that required CredSSP reset
			# $errorSessions: unreachable, failed CredSSP reset, or failed initial PSRemote connection after CredSSP reset
			# $tryResetSessions: systems that failed double-hop access
			
			# for any systems in $tryResetSessions, try resetting CredSSP with PSExec
			
			#region STAGE 3a: Reset CredSSP on systems that failed network double-hop access
			if ($tryResetSessions.Count) {
				Write-Log -Message "STAGE 3a: Reset CredSSP on systems that failed network double-hop access..."
				$num = $tryResetSessions.Count
				$curr = 1
				
				foreach ($sysName in @($tryResetSessions.Keys)) {
					Write-Progress -Activity "STAGE 3a: Reset CredSSP on systems that failed network double-hop access..." -PercentComplete ([int](($curr++ / $num) * 100)) -Status $sysName
					
					# Cannot access server with CredSSP, try to use PSExec to enable CredSSP access and retry
					$resetWorked = Setup-CredSSP -setupName $sysName -setupcredential $Credential
					
					if (-not $resetWorked) {
						$goodSessions.Remove($sysName)
						$tryResetSessions.Remove($sysName)
						$errorSessions.Add($sysName, "ERROR > Error resetting CredSSP on '$sysName'!")
					} #end if
				} #end for
			} #end if
			
			Write-Progress -Activity "STAGE 3a: Reset CredSSP on systems that failed network double-hop access..." -Completed
			#endregion 
			
			# $goodSessions: systems that have passed all tests so far
			# $warningSessions: systems that required CredSSP reset
			# $errorSessions: unreachable, failed CredSSP reset, failed initial PSRemote connection, or failed network double-hop access
			# $tryResetSessions: systems that failed network double-hop access and had CredSSP successfully reset
			
			# for any systems in $tryResetSessions, retry network double-hop access
			
			#region STAGE 3b: Recheck systems that had CredSSP reset for network double-hop access
			if ($tryResetSessions.Count) {
				Write-Log -Message "STAGE 3b: Recheck systems that had CredSSP reset for network double-hop access..."
				$num = $tryResetSessions.Count
				$curr = 1
				
				foreach ($sysName in @($tryResetSessions.Keys)) {
					Write-Progress -Activity "STAGE 3b: Recheck systems that had CredSSP reset for network double-hop access..." -PercentComplete ([int](($curr++ / $num) * 100)) -Status $sysName
					Write-Log -Message "Testing network double-hop access for '${sysName}'..."
					
					$newSession = $null
					$sessOpts = New-PSSessionOption -NoMachineProfile -OpenTimeout 5000 -CancelTimeout 5000 -IdleTimeout 60000 -OperationTimeout 60000
					$testSession = New-PSSession -ComputerName $sysName -EnableNetworkAccess -Credential $Credential -Authentication Credssp -ErrorAction SilentlyContinue -SessionOption $sessOpts
					$testResult = Invoke-Command -Session $testSession -ScriptBlock $testScript -ErrorAction SilentlyContinue
					
					if ($testResult -and
						$testResult.psobject -and
						$testResult.psobject.TypeNames -and
						$testResult.psobject.TypeNames -icontains "Deserialized.System.IO.DirectoryInfo") {
						Write-Log -Message "SUCCESS: After resetting CredSSP, verified network double-hop access from '${sysName}'!"
						$warningSessions.Add($sysName, "WARNING > After resetting CredSSP, verified network double-hop access from '$sysName'!")
						$goodSessions.$sysName = $testSession
					} else {
						Write-Log -Message "ERROR > Could not verify network double-hop access even after resetting CredSSP on '${sysName}'!"
						$errorSessions.Add($sysName, "ERROR > Could not verify network double-hop access even after resetting CredSSP on '$sysName'!")
					}
				} #end for
			} #end if
			
			$tryResetSessions.Clear()
			Write-Progress -Activity "STAGE 3b: Recheck systems that had CredSSP reset for network double-hop access..." -Completed
			#endregion 
		}
		# $goodSessions: systems that have passed all tests so far
		# $warningSessions: systems that required CredSSP reset
		# $errorSessions: unreachable, failed CredSSP reset, failed initial PSRemote connection, or failed network double-hop access
		# $tryResetSessions: cleared
	} # end process block
	
	End {
		if ($goodSessions.Count) {
			$goodSessions, $errorSessions, $warningSessions
		} else {
			@(), $errorSessions, $warningSessions
		}
	} # end of end block
}

#----------------------------------------------------------------------------------------

Function Test-PSRemoting {
<#
	Purpose:		Test-PSRemoting connections to a list of servers
	Inputs:
		ComputerName:	array of system names to test against
		credential:		user credential to use (default empty)
	Output:
		Console output 
#>
	[CmdletBinding()]
	Param (
		[string[]]$ComputerName,
		
		[pscredential]$Credential = [pscredential]::Empty,
		
		[Parameter()]
		[switch]$noDoubleHop
	)
	
	if (-not $ComputerName) {
		# error if input list is empty
		Write-Log -Message "Invalid or empty server list!  Failing..."
		return $null
	}
	
	if ($Credential -eq [pscredential]::Empty) {
		# get credential for remote access if not supplied
		$Credential = Get-UserCredential
		
		if (-not $Credential) {
			# error if credential cannot be retrieved
			Write-Log -Message "Unable to retrieve user credential! Failing..."
			return $null
		}
	}
	
	# list of sessions that failed or required remediation
	$errorSessions = @{
	}
	$warningSessions = @{
	}
	
	# open sessions for the list of server names with the credential
	$goodSessions, $errorSessions, $warningSessions = Open-ServerSessions -ComputerName $ComputerName -Credential $Credential -noDoubleHop:$noDoubleHop
	
	if ($goodSessions) {
		Write-Log -Message "SESSIONS ESTABLISHED SUCCESSFULLY: $($goodSessions.Count)"
		$goodSessions | Format-Table -AutoSize
		
		# Close any open sessions, since this was just a test
		Get-PSSession | Remove-PSSession -ErrorAction SilentlyContinue
	} else {
		# unable to establish any sessions at all, return error
		Write-Log -Message "Unable to establish any sessions!  Failing..."
		return $null
	}
	
	if ($errorSessions.Count) {
		# if there were failed connections, dump their names
		Write-Log -Message "SESSIONS WITH FAILURES:"
		foreach ($key in $errorSessions.keys) {
			Write-Log -Message ($errorSessions.$key)
		}
	} else {
		Write-Log -Message "NO SESSION FAILURES"
	}
	
	if ($warningSessions.Count) {
		# if there were remediated connections, dump their names
		Write-Log -Message "SESSIONS WITH WARNINGS: $($warningSessions.Count)"
		foreach ($key in $warningSessions.keys) {
			Write-Log -Message ($warningSessions.$key)
		}
	} else {
		Write-Log -Message "NO SESSION WARNINGS"
	}
} # end function

#----------------------------------------------------------------------------------------

Function Get-UserCredential {
<#
	Purpose:		Get credential from prepopulated file "$env:username.credfile.XML"
					NOTE: Only the current user will have access to the contents of the credential file
					- OR -
					If that fails, prompt the user interactively for credential
					If that fails, error out
	Inputs:			optional path to filename to get credential from
	Output:			[pscredential] on success, $null on error
#>
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline = $true)]
		[System.IO.FileInfo]$credFile = "$env:userprofile\$env:username.credfile.xml",
		
		[Parameter()]
		[switch]$debugIt
	)
	
	Begin { }
	
	Process {
		# Make sure CSV exists
		If (Test-Path ($credFile)) {
			if ($debugIt) { Write-Log -Message "Checking for credential file '$credFile'..." }
			
			# get credential from .CSV
			$Credential = Import-CliXml -Path $credFile -ErrorAction SilentlyContinue
			
			If ($Credential) {
				# return credential extracted from file
				if ($debugIt) { Write-Log -Message "Using credential from '$credFile'..." }
				return $Credential
			} else {
				# credential could not be extracted from specified file
				Write-Log -Message "Unable to use credential from '$credFile'..."
			}
		} else {
			# file missing or otherwise inaccessible
			Write-Log -Message "Credential file '$credFile' not available!"
		}
		
		# Prompt user for credential
		Write-Log -Message "Credential not found on disk.  Prompting..."
		$userName = "$env:userdomain\$env:username"
		$Credential = Get-Credential -Message "Please enter your network credential" -UserName $userName -ErrorAction SilentlyContinue
		
		If ($Credential) {
			# return credential returned from user
			Write-Log -Message "Using credential from user..."
			return $Credential
		} else {
			# error with user-supplied credential
			Write-Log -Message "Unable to use credential from prompt!"
		}
		
		# unable to get any credential, error
		Write-Log -Message "Unable to get network credential for '$($env:username)'!  Failing..."
		return [pscredential]::Empty
	}
	
	End { }
} # end function

#----------------------------------------------------------------------------------------

Function New-UserCredential {
<#
	Purpose:		return a new credential object from supplied username and password
					- OR -
					Create a new credential file "$env:username.credfile.XML"
					NOTE: Only the current user will have access to the contents of the credential file
					- OR -
					Prompt the user interactively for credential and return

	Inputs:			username
					password
					optional path to filename to export new credential

	Output:			new [pscredential] created on success, empty credential on error
#>
	[CmdletBinding()]
	Param (
		[string]$userName = "$env:userdomain\$env:username",
		
		[string]$Password = "",
		
		[string]$credFile = ""
	)
	
	
	if ($Password -eq "") {
		$Credential = Get-Credential -Message "Please enter your network credential" -UserName $userName -ErrorAction SilentlyContinue
	} else {
		$Credential = New-Object -TypeName pscredential -ArgumentList $userName, ($Password | ConvertTo-SecureString -AsPlainText -Force) -ErrorAction SilentlyContinue
	}
	
	If ($Credential) {
		# return credential returned from user
		#Write-Log -Message "Using credential from user..."
		if ($credFile) {
			$Credential | Export-CLIXML -Path $credfile -ErrorAction SilentlyContinue
		}
		
		return $Credential
	}
	
	# unable to use supplied credential, return nothing
	return [pscredential]::Empty
} # end function

#----------------------------------------------------------------------------------------

Function Get-PlainText () {
<#
	Purpose:		Get the plaintext password from a [pscredential] object
	Inputs:
		password:	encrypted password from [pscredential]
	Output:			plaintext password 
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[securestring]$Password
	)
	
	Begin { }
	
	Process {
		# Extract the plain text from the specified credential
		return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
	}
	
	End { }
} # end function

#----------------------------------------------------------------------------------------

Function Setup-CredSSP {
<#
	Inputs:
		setupName:	name of system to attempt to set up CredSSP on
		setupcredential:	credential of user to setup credential with PSExec
	Output:			$false on failure, $true on success 
#>
	[CmdletBinding()]
	Param (
		[string]$setupName,
		
		[pscredential]$setupcredential
	)
	
	Begin { }
	
	Process {
		#write-host "a"
		# Get path to PSEXEC.EXE on current path
		$PSExecName = "PSExec.EXE"
		$PSExecPath = (Get-Content env:path) -split ";" | ForEach-Object {
			if (Test-Path "$_\$PSExecName") {
				"$_\$PSExecName"
			}
		} | Select-Object -First 1
		
		if (([System.IO.FileInfo]$PSExecPath).Exists) {
			# PSExec available on path
			Write-Log -Message "Using PSEXEC.EXE from '$PSExecPath'"
		} else {
			# Abort all if no PSEXEC on path
			Write-Log -Message "ERROR > PSEXEC not available!  Aborting.."
			return $false
		}
		
		# Prep plaintext username and password
		$userName = $setupcredential.UserName
		$passwd = (Get-PlainText $setupcredential.Password)
		# Setup PSExec remote command
		$remoteCommand = 'echo . | powershell.exe -command "&" { Enable-PSRemoting -Force; Enable-WSManCredSSP -Role Server -Force; Restart-Service RemoteRegistry -Force; Restart-Service WinRM -Force; Get-WSManCredSSP; }'
		
		Write-Log -Message "Resetting CredSSP on '${setupName}'..."
		
		# Execute PSEXEC, redirecting error output to $null
		$result = & $psexecPath \\${setupName} /acceptEula -u ${userName} -p ${passwd} -h cmd /c ${remoteCommand} 2> $null
		
		# search for string "CredSSP : true" in results
		if ($result | Select-String "CredSSP[\s]+:[\s]true") {
			# success detected
			Write-Log -Message "SUCCESS: CredSSP successfully reset on '${setupName}'!"
			return $true
		} else {
			# failure detected
			Write-Log -Message "ERROR > Failed to reset CredSSP on '${setupName}'!"
			return $false
		}
	}
	
	End { }
} # end function

#----------------------------------------------------------------------------------------

Function ForEach-System {
<#
	.SYNOPSIS
		Apply a scriptblock to a specified list of systems
	
	.DESCRIPTION
		This Function takes a list of system names and runs a script on each 
		then returns the results.  The list of system names can be piped in, 
		specified on the command line or listed in a file.  The scriptblock 
		can be specified on the command line or in a file.
		
		NOTE: Path is relative to the script, not the user's home directory.
		
		NOTE: The path supplied must be a valid Powershell path or the 
		Function errors out.
	
	.PARAMETER nameFile
		Valid path to the list of names of each system where to execute the 
		scriptblock.  The format of the file is standard .CSV, one line 
		per system.  You can include whatever fields you wish, but 
		currently only a single field of "SystemName" is required.  Prefacing 
		a system name with "#" will ignore that line.
		
		NOTE: Recommend using FQDN network name format.
	
	.PARAMETER ComputerName
		Type [string[]]
		Array of names of each system where to execute the scriptblock. 
		A system name prefaced with "#" will be ignored.
		
		NOTE: Recommend using FQDN network name format.
	
	.PARAMETER ScriptFile
		Valid path to a text file containing a valid Powershell script 
		to execute on each system.  The output of this scriptblock will be 
		returned from this Function as an array.
		
		NOTE: Path is relative to the script, not the user's home directory.
	
	.PARAMETER remoteScript
		Type [scriptblock]
		A valid Powershell scriptblock to execute on each system.  The 
		output of this scriptblock will be returned from this Function as 
		an array.
	
	.PARAMETER credential
		Type [pscredential]
		credential for connecting to and running the script on each 
		listed system.  This can be specified on the command line as 
		the output from (Get-Credential), as a user-constructed 
		[pscredential] or a preset file containing encrypted credential. 
		
		The path to this file is "$env:username.credfile.XML"
		
		NOTE: To create this file use the following command from 
		Powershell command line:
		(Get-Credential -username "$env:userdomain\$env:username") | 
			Export-CLIXML -Path "$env:USERPROFILE\$env:username.credfile.xml"
		
		NOTE: Only the current user will have access to the contents 
		of the credential file
		
		NOTE: If the credential file fails, the user will be prompted
		interactively for credential.
		
		NOTE: If interactive prompting fails, the Function errors out.
	
	.PARAMETER testOnly
		This specifies that the Function will loop through each system 
		and verify it is:
			1) Accessible over the network via ping
			2) Accessible as local administrator by the supplied user 
			credential
			3) Accessible through PSRemoting using CredSSP authentication
			4) Able to reach the domain SYSVOL over the network with 
			the supplied user credential
		If a system is not available for all criteria, the user will be
		notified.
		
		NOTE: The check for network accessibility is a good result for
		the command "dir \\VZB\Sysvol"
		
		NOTE: This parameter overrides the scriptblock parameters
		-remoteScript and -ScriptFile.  ONLY accessibility checks are
		performed.
		
		NOTE: The Function uses PSExec.EXE to attempt to enable 
		PSRemoting on the target system if the access to the system 
		fails OR if the system does not have network access.  If either 
		fails, PSExec.EXE MUST be on the current path.
		
		NOTE: If PSExec is used, it will be passed the -cred credential 
		to run under.
	
	.PARAMETER showProgress
		Type [switch], default $true
		Show a progress meter as each system is looped through.
	
	.PARAMETER throtteLimit
		Type [int], default 10
		Maximum systems the Function will contact at one time to run 
		the scriptblock.
		
	.PARAMETER debugIt
		Debugging on (passed to target)
	
	.EXAMPLE
		PS C:\> ForEach-System -nameFile $path -remoteScript $sb
		
		Run [scriptblock]$sb on each system specified in $path, return 
		results in array
	
	.EXAMPLE
		PS C:\> $sysList = system1, system2, system3
				$sb = [scriptblock]::create("dir c:\")
				$sysList | ForEach-System -remoteScript $sb
		
		Get a directory listing of C: on system1, system2 and system3
	
	.EXAMPLE
		PS C:\> $sysList = system1, system2, system3
				$sysList | ForEach-System -testOnly
				
		Test system1, system2 and system3 for use with this function
	
	.EXAMPLE
		PS C:\> $sysList = system1, system2, system3
				"dir c:\" | Set-Content c:\Temp\getc.ps1
				$sysList | ForEach-System -ScriptFile c:\Temp\getc.ps1
		
		Create an external file 'c:\Temp\getc.ps1' and run that
		script against system1, system2 and system3
	
	.OUTPUTS
		[psobject[]] of results passed from supplied scriptblock
		
		NOTE: If the output the script is type [hashtable], the hash 
		is converted to an object with identical properties
	
		NOTE: Each object in the output array is extended by the
		additional property [string]PSComputerName holding the name 
		of the system the output is from.
		
		NOTE: Any inaccessible systems are returned as error objects.
#>
	[CmdletBinding(DefaultParameterSetName = 'ComputerNameScriptText')]
	Param (
		[Parameter(Mandatory = $true,
				   ParameterSetName = "ComputerNameScriptText")]
		[Parameter(Mandatory = $true,
				   ParameterSetName = "ComputerNameScriptFile")]
		[Parameter(Mandatory = $true,
				   ParameterSetName = "ComputerNameTest")]
		[Alias('CN', '__Server', 'IPAddress', 'Server', 'SystemName', 'Name', 'NameList')]
		[string[]]$ComputerName,
		
		[Parameter(Mandatory = $true,
				   ParameterSetName = "NameFileScriptText")]
		[Parameter(Mandatory = $true,
				   ParameterSetName = "NameFileScriptFile")]
		[Parameter(Mandatory = $true,
				   ParameterSetName = "NameFileTest")]
		[System.IO.FileInfo]$nameFile,
		
		[Parameter(Mandatory = $true,
				   ParameterSetName = "NameFileScriptFile")]
		[Parameter(Mandatory = $true,
				   ParameterSetName = "ComputerNameScriptFile")]
		[System.IO.FileInfo]$scriptFile,
		
		[Parameter(Mandatory = $true,
				   ParameterSetName = "NameFileScriptText")]
		[Parameter(Mandatory = $true,
				   ParameterSetName = "ComputerNameScriptText")]
		[scriptblock]$scriptText,
		
		[Parameter(Mandatory = $true,
				   ParameterSetName = "NameFileTest")]
		[Parameter(Mandatory = $true,
				   ParameterSetName = "ComputerNameTest")]
		[switch]$testOnly,
		
		[Parameter()]
		[Alias('RunAs', 'Cred')]
		[pscredential]$Credential = [pscredential]::Empty,
		
		[Parameter()]
		[switch]$showProgress,
		
		[Parameter()]
		[switch]$noDoubleHop,
		
		[Parameter()]
		[int]$throtteLimit = 10,
		
		[Parameter()]
		[int]$Retries = 2,
		
		[Parameter()]
		[int]$remoteTimeout = 10,
		
		[Parameter()]
		[switch]$debugIt,
		
		[Parameter()]
		[string]$logPath = "",
		
		[Parameter()]
		[string[]]$limitTo = @(""),
		
		[Parameter()]
		[string[]]$exclude = @("")
	)
	
	begin {
		$invokeErrors = @()
		$connectErrors = @()
		
		if ($logPath) {
			$saveLogfile = $global:logFile
			$global:logFile = $logPath
		}
	}
	
	process {
		if (((Get-Job).Name) -icontains "InvokeJob-$global:invokeJobGUID") {
			Get-Job -Name "InvokeJob-$global:invokeJobGUID" | Remove-Job -ErrorAction SilentlyContinue
		}
		
		if ($debugIt) { Write-Log -Message "DEBUG > `$Credential = '$($Credential.UserName)'" }
		
		if ($PSCmdlet.ParameterSetName -ilike '*NameFile*') {
			# passing in server names by file
			$Names = @()
			$ComputerName = @()
			#massage path to be relative to script directory
			$nameFile = Convert-Path $nameFile -ErrorAction SilentlyContinue
			
			# Pull in list of server names from file
			if (-not $nameFile) {
				Write-Log -Message "ERROR > Invalid or empty server list file '$($nameFile.Fullname)'! Exiting..."
				return $null
			} else {
				if ($debugIt) { Write-Log "`$nameFile = '$nameFile'" }
				Write-Log -Message "File '$($namefile.Fullname)' exists!  Importing list..."
				# import CSV of servernames with at least one column named "SystemName"
				$Names = Get-SysNamesFromFile $nameFile -limitTo $limitTo
				
				if ($Names) {
					#strip CSV format to array of names
					$Names = $Names | Where-Object SystemName -NotMatch '^#.*$'
					$ComputerName = $Names.SystemName.Trim()
				}
			}
		}
		
		if ($PSCmdlet.ParameterSetName -ilike '*ComputerName*') {
			if ($debugIt) { Write-Log -Message "DEBUG > `$ComputerName = '$ComputerName'" }
			$Names = Get-SysNamesFromText -computerName $ComputerName -defaultCredential $Credential -limitTo $limitTo
		}
		
		if ($Names) {
			"-----------System Names-----------" | Write-Log
			$Names | Write-Log
		} else {
			Write-Log -Message "ERROR > Invalid or empty server list! Exiting..."
			return $null
		}
		
		if ($testOnly) {
			# only run connection tests and return
			Write-Log -Message "Testing and enabling PSRemoting and double-hop network access to server list..."
			Test-PSRemoting -Credential $Credential -ComputerName $Names.SystemName -noDoubleHop:$noDoubleHop
			return
		}
		
		if ($scriptFile) {
			# remote script is in an external file
			$scriptFile = Convert-Path $scriptFile -ErrorAction SilentlyContinue
			$scriptName = (Get-ChildItem $scriptFile).Basename
			
			if (-not $scriptFile) {
				Write-Log -Message "ERROR > Invalid or empty remote script file '$($scriptFile.Fullname)'! Exiting..."
				return $null
			} else {
				Write-Log -Message "Script file '$($scriptFile.Fullname) exists!"
				# import script from file
				$remoteText = (Get-Content $scriptFile -raw -ErrorAction SilentlyContinue)
				
				if ($remoteText) {
					#create scriptblock from file contents
					$scriptText = [scriptblock]::Create($remoteText)
				}
			}
		} else {
			$scriptName = "_RemoteFunctions_v3"
		}
		
		if (-not $scriptText) {
			Write-Log -Message "ERROR > Invalid or empty remote script! Exiting..."
			return $null
		}
		
		# Close all open jobs created by previous scripts
		$allJobs = @(Get-Job -IncludeChildJob | Where-Object { $_.Name -imatch "^InvokeJob-$($global:invokeJobGUID).*" })
		Write-Log -Message "# of jobs already active: $($allJobs.Count)"
		$allJobs | Remove-Job -Force -ErrorAction SilentlyContinue
		
		# Close all open sessions created by previous scripts
		$allSessions = @(Get-PSSession | Where-Object { $_.Name -imatch "^InvokeSession-$($global:invokeJobGUID).*" })
		Write-Log -Message "# of PSSessions already active: $($allSessions.Count)"
		$allSessions | Remove-PSSession -ErrorAction SilentlyContinue
		
		$Error.Clear()
		$invokeError = @()
		$connectError = @()
		$runError = @()
		$Output = @()
		$startedJobs = @()
		
		# Get the GUID job name common to all remote jobs
		$jobName = "InvokeJob-$($global:invokeJobGUID)"
		if ($debugIt) { Write-Log -Message "DEBUG > `$jobName = 'InvokeJob-$($global:invokeJobGUID)'" }
		
		# Set up session options for all sessions
		$sessOpts = New-PSSessionOption -NoMachineProfile -OpenTimeout 5000 -CancelTimeout 5000 -IdleTimeout 60000 -OperationTimeout 60000
		
		# TODO : Run remote script on each server in list (using parallelism options of PSSessions)
		
		foreach ($System in $Names) {
			Write-Log -Message "`n-------------SYSTEM: $($System.SystemName)----------------"
			
			if ($debugIt) { Write-Log -Message "DEBUG > `$System.Credential.Username = '$($System.Credential.Username)'" }
			if ($debugIt) { Write-Log -Message "DEBUG > `$System.Credential.Password = '********'" }
			if ($debugIt) { Write-Log -Message "DEBUG > `$global:logfile = $($global:logfile)" }
			
			# Build the session name for the remote system
			$sessionName = "InvokeSession-$global:invokeJobGUID-$($System.SystemName)"
			if ($debugIt) { Write-Log -Message "DEBUG > `$sessionName = 'InvokeSession-$global:invokeJobGUID-$($System.SystemName)'" }
			
			Write-Log -Message "Opening session for $($System.SystemName)"
			$connectSession = $null
			$connectSession = New-PSSession -ComputerName $System.SystemName -Credential $System.Credential -Authentication Credssp -EnableNetworkAccess -Name $sessionName -SessionOption $sessOpts -ErrorVariable +connectError -ErrorAction SilentlyContinue
			
			# For every remote system, invoke the specified script as a job with a unique job ID
			if ($connectSession) {
				Write-Log -Message "Opened session for $($System.SystemName)..."
				Write-Log -Message "Invoking job for $($System.SystemName)..."
				$invokeJob = $null
				$invokeJob = Invoke-Command -Session $connectSession -ScriptBlock $scriptText -AsJob -JobName $jobName -ThrottleLimit $throtteLimit -ErrorVariable +invokeError -ErrorAction SilentlyContinue
				
				if ($invokeJob) {
					Write-Log -Message "Invoked job for $($System.SystemName)"
					$startedJobs += $invokeJob.ChildJobs
				} else {
					Write-Log -Message "ERROR >>> Cannot invoke job for $($System.SystemName)!"
				}
			} else {
				Write-Log -Message "ERROR >>> Cannot open session to $($System.SystemName)!"
			}
		}
		
		Write-Log -Message "`n---------------SUMMARY---------------"
		
		# log the number of jobs actually created
		Write-Log -Message "Total Jobs: $($startedJobs.Count)"
		
		# Get the initial available results from each job
		if ($startedJobs) {
			$startedJobs | Get-Job -IncludeChildJob -ErrorAction SilentlyContinue -ErrorVariable +runError | Out-Null
		}
		
		if ($debugIt) { Write-Log -Message "DEBUG > `$runError = '$runError'" }
		
		# Log the total # of jobs attempted
		$numJobs = $ComputerName.Count
		Write-Log -Message "Total # of Running Jobs  = $numJobs"
		
		$rec = 0
		
		if ($startedJobs) {
			do {
				# Get the next pass of available results from each job
				$startedJobs | Get-Job -IncludeChildJob -ErrorAction SilentlyContinue -ErrorVariable runError | Out-Null
				
				# Get the number of jobs actually completed (successfully or unsuccessfully)
				$completedJobs = ($startedJobs | Where-Object State -eq "Completed").Count
				
				if ($showProgress) {
					Write-Progress -Activity "Waiting for remote jobs" -Status "Percentage completed" -PercentComplete ([int]($completedJobs/$numJobs * 100))
				}
				# loop until there are no more running jobs
			}
			while ($startedJobs.State -ieq "Running")
		}
		
		Write-Progress -Activity "Waiting for remote jobs" -Completed
		
		# Gather the final output of all jobs
		if ($startedJobs) {
			$Output += $startedJobs | Receive-Job -Keep -ErrorAction SilentlyContinue -ErrorVariable +runError
			if ($debugIt) { Write-Log -Message "Output struct:" }
			#Write-Log -Message ($Output | Get-Member -Force | Out-String)
		}
		
		if ($connectError) {
			# Log and display any connection errors encountered
			Write-Log -Message "Connection Errors: $($connectError.Count)"
			$connectError | ForEach-Object {
				#Write-Log -Message "$($_.OriginInfo.PSComputerName) - $_"
				Write-Log -Message "ERROR >>> $_"
			}
		} else {
			if ($debugIt) { Write-Log "No Connection Errors!" }
		}
		
		if ($invokeError) {
			# Log and display any job execution errors encountered
			Write-Log -Message "Invoke Errors: $($invokeError.Count)"
			$invokeError | ForEach-Object {
				#Write-Log -Message "$($_.OriginInfo.PSComputerName) - $_"
				Write-Log -Message "ERROR >>> $_"
			}
		} else {
			if ($debugIt) { Write-Log "No Invoke Errors!" }
		}
		
		if ($runError) {
			# Log and display any job execution errors encountered
			Write-Log -Message "Run Errors: $($runError.Count)"
			$runError | ForEach-Object {
				Write-Log -Message "ERROR > $_"
			}
		} else {
			if ($debugIt) { Write-Log "No Run Errors!" }
		}
		
		if (-not $Output) {
			Write-Log -Message "DEBUG > No output available!"
		} else {
			Write-Log -Message "DEBUG > Final output:"
			#$OutputFormat = @{ Name = "PSComputerName"; Expression = { $_.PSComputerName } }#, @{Name = "Text"; Expression = { $_ } }
			#$Output = $Output | Select-Object -Property PSComputerName, *
			#$Output | ForEach-Object { Write-Log -Message "$($_.PSComputerName) : $($_.Text)" }
			#Write-Log -Message "`$(`$Output.PSComputerName) = '$($Output.PSComputerName)' $($Output.gettype())"
			$Output | Write-Log #ForEach-Object {
			#			"$($_.PSComputerName)"
			#			"$($_.GetType())"
			#			"$_"
			#			Write-Log $_
			#		}
		}
	}
	
	end {
		if ($logPath) {
			$global:logFile = $saveLogfile
		}
	}
}

#----------------------------------------------------------------------------------------

Function Invoke-WUInstallCustom {
	<#
	.SYNOPSIS
		Invoke Get-WUInstall remotely.

	.DESCRIPTION
		Use Invoke-WUInstall to invoke Windows Update install remotly. It Based on TaskScheduler because 
		CreateUpdateDownloader() and CreateUpdateInstaller() methods can't be called from a remote computer - E_ACCESSDENIED.
		
		Note:
		Because we do not have the ability to interact, is recommended use -AcceptAll with WUInstall filters in script block.
	
	.PARAMETER ComputerName
		Specify computer name.

	.PARAMETER TaskName
		Specify task name. Default is PSWindowsUpdate.
		
	.PARAMETER Script
		Specify PowerShell script block that you what to run. Default is {ipmo PSWindowsUpdate; Get-WUInstall -AcceptAll | Out-File C:\PSWindowsUpdate.log}
		
	.EXAMPLE
		PS C:\> $Script = {ipmo PSWindowsUpdate; Get-WUInstall -AcceptAll -AutoReboot | Out-File C:\PSWindowsUpdate.log}
		PS C:\> Invoke-WUInstall -ComputerName pc1.contoso.com -Script $Script
		...
		PS C:\> Get-Content \\pc1.contoso.com\c$\PSWindowsUpdate.log
		
	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/

	.LINK
		Get-WUInstall
	#>
	[CmdletBinding()]
	Param
	(
		[Parameter(ValueFromPipeline = $True,
				   ValueFromPipelineByPropertyName = $True)]
		[String[]]$ComputerName,
		
		[String]$TaskName = "PSWindowsUpdate",
		
		[ScriptBlock]$Script = { Import-Module PSWindowsUpdate; Get-WUInstall -AcceptAll | Out-File C:\PSWindowsUpdate.log },
		
		[Switch]$OnlineUpdate,
		
		[Parameter(ValueFromPipeline = $True,
				   ValueFromPipelineByPropertyName = $True)]
		[pscredential]$Credential = [pscredential]::Empty
	)
	
	Begin {
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
		
		if (!$Role) {
			Write-Log -Message "To perform some operations you must run an elevated Windows PowerShell console."
		} #End If !$Role
		
		# Get version of PSWindowsUpdate module that is local
		# Only use the latest version if multiple available
		$PSWUModule = @(Get-Module -Name PSWindowsUpdate -ListAvailable) | Sort-Object | Select-Object -Last 1
		
		Write-Log -Message "Create schedule service object"
		$Scheduler = New-Object -ComObject Schedule.Service
		
		$Task = $Scheduler.NewTask(0)
		
		$RegistrationInfo = $Task.RegistrationInfo
		$RegistrationInfo.Description = $TaskName
		$RegistrationInfo.Author = $User.Name
		
		$Settings = $Task.Settings
		$Settings.Enabled = $True
		$Settings.StartWhenAvailable = $True
		$Settings.Hidden = $False
		
		$Action = $Task.Actions.Create(0)
		$Action.Path = "powershell"
		$Action.Arguments = "-Command $Script"
		
		$Task.Principal.RunLevel = 1
	}
	
	Process {
		ForEach ($Computer in $ComputerName) {
			if (Test-Connection -ComputerName $Computer -Quiet) {
				Write-Log -Message "Check PSWindowsUpdate module on $Computer"
				try {
					$ModuleTest = Invoke-Command -ComputerName $Computer -ScriptBlock { @(Get-Module -Name PSWindowsUpdate -ListAvailable) | Sort-Object | Select-Object -Last 1 } -Credential $Credential -ErrorAction Stop -Authentication Credssp
				} catch {
					Write-Log -Message "Can't connect to machine $Computer. Try use: winrm qc"
					Continue
				} #End Catch
				$ModuleStatus = $false
				
				if ($ModuleTest -eq $null -or $ModuleTest.Version -lt $PSWUModule.Version) {
					if ($OnlineUpdate) {
						Update-WUModuleCustom -ComputerName $Computer
					} else {
						Update-WUModuleCustom -ComputerName $Computer -LocalPSWUSource (@(Get-Module -Name PSWindowsUpdate -ListAvailable) | Sort-Object | Select-Object -Last 1).ModuleBase -Credential $Credential
					}
				}
				
				#Sometimes can't connect at first time
				$Info = "Connect to scheduler and register task on $Computer"
				for ($i = 1; $i -le 3; $i++) {
					$Info += "."
					Write-Log -Message $Info
					try {
						$User = $Credential.UserName -replace "^.*\\", ""
						$Domain = $Credential.UserName -replace "\\.*", ""
						$Scheduler.Connect($Computer, $User, $Domain, (Get-PlainText $Credential.Password))
						Break
					} catch {
						if ($i -ge 3) {
							Write-Error "Can't connect to Schedule service on $Computer" -ErrorAction Stop
						} else {
							Start-Sleep -Seconds 1
						} #End Else $i -ge 3
					} #End Catch					
				} #End For $i=1; $i -le 3; $i++
				
				$RootFolder = $Scheduler.GetFolder("\")
				$SendFlag = 1
				if ($Scheduler.GetRunningTasks(0) | Where-Object { $_.Name -eq $TaskName }) {
					$CurrentTask = $RootFolder.GetTask($TaskName)
					$Title = "Task $TaskName is curretly running: $($CurrentTask.Definition.Actions | Select-Object -exp Path) $($CurrentTask.Definition.Actions | Select-Object -exp Arguments)"
					$Message = "What do you want to do?"
					
					$ChoiceContiniue = New-Object System.Management.Automation.Host.ChoiceDescription "&Continue Current Task"
					$ChoiceStart = New-Object System.Management.Automation.Host.ChoiceDescription "Stop and Start &New Task"
					$ChoiceStop = New-Object System.Management.Automation.Host.ChoiceDescription "&Stop Task"
					$Options = [System.Management.Automation.Host.ChoiceDescription[]]($ChoiceContiniue, $ChoiceStart, $ChoiceStop)
					$SendFlag = $host.ui.PromptForChoice($Title, $Message, $Options, 0)
					
					if ($SendFlag -ge 1) {
						($RootFolder.GetTask($TaskName)).Stop(0)
					} #End If $SendFlag -eq 1	
					
				} #End If !($Scheduler.GetRunningTasks(0) | Where-Object {$_.Name -eq $TaskName})
				
				if ($SendFlag -eq 1) {
					$RootFolder.RegisterTaskDefinition($TaskName, $Task, 6, "SYSTEM", $Null, 1) | Out-Null
					$RootFolder.GetTask($TaskName).Run(0) | Out-Null
				} #End If $SendFlag -eq 1
				
				#$RootFolder.DeleteTask($TaskName,0)
			} else {
				Write-Log -Message "Machine $Computer is not responding."
			} #End Else Test-Connection -ComputerName $Computer -Quiet
		} #End ForEach $Computer in $ComputerName
		Write-Log -Message "Invoke-WUInstall complete."
	}
	
	End { }
	
}

#----------------------------------------------------------------------------------------

Function Update-WUModuleCustom {
	<#
	.SYNOPSIS
		Invoke Get-WUInstall remotely.

	.DESCRIPTION
		Use Invoke-WUInstall to invoke Windows Update install remotely. It is based on TaskScheduler because the
		CreateUpdateDownloader() and CreateUpdateInstaller() methods can't be called from a remote computer (E_ACCESSDENIED)
		
		Note:
		Because we do not have the ability to interact, is recommended to use -AcceptAll with WUInstall filters in script block.
	
	.PARAMETER ComputerName
		Specify computer name.

	.PARAMETER PSWUModulePath	
		Destination of PSWindowsUpdate module. Default is $PSHOME\Modules\PSWindowsUpdate
	
	.PARAMETER OnlinePSWUSource
		Link to online source on TechNet Gallery.
		
	.PARAMETER LocalPSWUSource	
		Path to local source on your machine. If you cant use [System.IO.Compression.ZipFile] you must manually 
		unzip source and set path to it.
			
	.PARAMETER CheckOnly
		Only check current version of PSWindowsUpdate module. Don't update it.
		
	.EXAMPLE
		PS C:\> Update-WUModule

	.EXAMPLE
		PS C:\> Update-WUModule -LocalPSWUSource "$PSHOME\Modules\PSWindowsUpdate" -ComputerName PC2,PC3,PC4
		
	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/

	.LINK
		Get-WUInstall
	#>
	
	[CmdletBinding()]
	Param
	(
		[Parameter(ValueFromPipeline = $True,
				   ValueFromPipelineByPropertyName = $True)]
		[String[]]$ComputerName = "localhost",
		
		[String]$PSWUModulePath = "$PSHOME\Modules\PSWindowsUpdate",
		
		[String]$OnlinePSWUSource = "http://gallery.technet.microsoft.com/2d191bcd-3308-4edd-9de2-88dff796b0bc",
		
		[String]$SourceFileName = "PSWindowsUpdate.ZIP",
		
		[String]$LocalPSWUSource,
		
		[Switch]$CheckOnly,
		
		[Switch]$Debugger,
		
		[Parameter(ValueFromPipeline = $True,
				   ValueFromPipelineByPropertyName = $True)]
		[pscredential]$Credential = [pscredential]::Empty
	)
	
	Begin {
		If ($PSBoundParameters['Debugger']) {
			$DebugPreference = "Continue"
		}
		
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
		
		if (!$Role) {
			Write-Log -Message "ERROR >>> To perform some operations you must run an elevated Windows PowerShell console!"
			return $false
		}
		
		if ($LocalPSWUSource -eq "") {
			Write-Log -Message "Preparing temp download location..."
			$TempDestination = [environment]::GetEnvironmentVariable("TEMP")
			$ZippedSource = Join-Path -Path $TempDestination -ChildPath $SourceFileName
			$TempSource = Join-Path -Path $TempDestination -ChildPath "PSWindowsUpdate"
			
			# Download PSWindowsUpdate module from web
			try {
				$WebClient = New-Object System.Net.WebClient
				$WebSite = $WebClient.DownloadString($OnlinePSWUSource)
				
				$matches = $null
				$WebSite -match "/file/41459/\d*/PSWindowsUpdate.zip" | Out-Null
				
				if ($matches) {
					$OnlinePSWUSourceFile = "$OnlinePSWUSource$($matches[0])"
					Write-Log -Message "Download latest PSWindowsUpdate module from website: $OnlinePSWUSourceFile"
					$WebClient.DownloadFile($OnlinePSWUSourceFile, $ZippedSource)
				} else {
					Write-Log -Message "ERROR >>> Unable to download the latest PSWindowsUpdate module from website: '$OnlinePSWUSourceFile'!"
					return $false
				}
			} catch {
				Write-Log -Message "ERROR >>> Unable to download the latest PSWindowsUpdate module from website: '$OnlinePSWUSourceFile'!"
				return $false
			}
			
			try {
				if (Test-Path $TempSource) {
					Write-Log -Message "Cleaning up old PSWindowsUpdate source..."
					Remove-Item -Path $TempSource -Force -Recurse
				}
				
				Write-Log -Message "Unzipping the latest PSWindowsUpdate module..."
				[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
				[System.IO.Compression.ZipFile]::ExtractToDirectory($ZippedSource, $TempDestination)
				$LocalPSWUSource = Join-Path -Path $TempDestination -ChildPath "PSWindowsUpdate"
			} catch {
				Write-Log -Message "Can't unzip the latest PSWindowsUpdate module!"
				return $false
			}
			
			Write-Log -Message "Unblocking the downloaded module..."
			Get-ChildItem -Path $LocalPSWUSource | Unblock-File -ErrorAction SilentlyContinue
		}
		
		$ManifestPath = Join-Path -Path $LocalPSWUSource -ChildPath "PSWindowsUpdate.psd1"
		$latestVersion = (Test-ModuleManifest -Path $ManifestPath).Version
		Write-Log -Message "The latest version of PSWindowsUpdate module is '$latestVersion'."
	}
	
	Process {
		ForEach ($Computer in $ComputerName) {
			if ($Computer -eq [environment]::GetEnvironmentVariable("COMPUTERNAME") -or $Computer -eq ".") {
				$Computer = "localhost"
			}
			
			if ($Computer -eq "localhost") {
				$ModuleTest = @(Get-Module -Name PSWindowsUpdate -ListAvailable) | Sort-Object | Select-Object -Last 1
			} else {
				if (Test-Connection $Computer -Quiet) {
					Write-Log -Message "Checking if PSWindowsUpdate module exists on '$Computer'..."
					
					try {
						$ModuleTest = Invoke-Command -ComputerName $Computer -ScriptBlock { @(Get-Module -Name PSWindowsUpdate -ListAvailable) | Sort-Object | Select-Object -Last 1 } -Credential $Credential -Authentication Credssp -ErrorAction SilentlyContinue
					} catch {
						Write-Log -Message "Can't access machine '$Computer'!"
						return $false
					}
				} else {
					Write-Log -Message "'$Computer' is not responding!"
					return $false
				}
			}
			
			if ($Computer -eq "localhost") {
				if ($ModuleTest.Version -lt $latestVersion) {
					if ($CheckOnly) {
						Write-Log -Message "Current version of PSWindowsUpdate module on '$Computer' is '$($ModuleTest.Version)'"
					} else {
						Write-Log -Message "Copying update module to '$Computer'..."
						Get-ChildItem -Path $LocalPSWUSource | Copy-Item -Destination $ModuleTest.ModuleBase -Force
						$afterUpdate = [String]((@(Get-Module -Name PSWindowsUpdate -ListAvailable) | Sort-Object | Select-Object -Last 1).Version)
						Write-Log -Message "$($Computer): Update completed!  Current version '$afterUpdate'"
					}
				} else {
					Write-Log -Message "The newest version of the PSWindowsUpdate module already exists on '$Computer'."
				}
			} else {
				Write-Log -Message "Connecting to '$Computer'..."
				
				if (($ModuleTest -eq $null) -or ($ModuleTest.Version -lt $latestVersion)) {
					$localDriveName = "foobaz"
					$DestinationDrive = "\\$Computer\c`$"
					$DestinationPath = $PSWUModulePath -replace "^.:\\", "${localDriveName}:"
					
					if ($CheckOnly) {
						if ($ModuleTest -eq $null) {
							Write-Log -Message "PSWindowsUpdate module on machine '$Computer' doesn't exist."
						} else {
							Write-Log -Message "Current version of PSWindowsUpdate module on machine $Computer is $($ModuleTest.Version)"
						}
					} else {
						if ($ModuleTest -eq $null) {
							Write-Log -Message "PSWindowsUpdate module on machine '$Computer' doesn't exist. Installing remotely to '$DestinationPath'..."
						} else {
							Write-Log -Message "Current version of PSWindowsUpdate module on machine $Computer is $($ModuleTest.Version)"
						}
						
						try {
							# kill any local SMB connections to remote server
							Remove-PSDrive -Name $localDriveName -Force -ErrorAction SilentlyContinue | Out-Null
							net use $DestinationDrive /d 2>&1 $null | Out-Null
							
							# create new SMB connection to remote server
							New-PSDrive -Name $localDriveName -PSProvider filesystem -Root $DestinationDrive -Credential $Credential | Out-Null
							New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
							
							# Copy file from local to remote drive location
							Get-ChildItem -Path $LocalPSWUSource | Copy-Item -Destination $DestinationPath -Force
							
							# kill any local SMB connections to remote server
							Remove-PSDrive -Name $localDriveName -force -ErrorAction SilentlyContinue | Out-Null
							net use $DestinationDrive /d 2>&1 $null | Out-Null
							
							$afterUpdate = [string](Invoke-Command -ComputerName $Computer -ScriptBlock { (@(Get-Module -Name PSWindowsUpdate -ListAvailable) | Sort-Object | Select-Object -Last 1).Version } -Credential $Credential -Authentication Credssp)
							Write-Log -Message "Update completed to '$Computer'. New version: '$afterUpdate'"
						} catch {
							Write-Log -Message "Can't install/update PSWindowsUpdate module on machine '$Computer'!"
							return $false
						}
					}
				} else {
					Write-Log -Message "Current version of PSWindowsUpdate module on machine '$Computer' is '$($ModuleTest.Version)'"
				}
			}
		}
	}
	
	End {
		if ($LocalPSWUSource -eq "") {
			Write-Log -Message "Cleaning up PSWindowsUpdate source..."
			if (Test-Path $ZippedSource -ErrorAction SilentlyContinue) {
				Remove-Item -Path $ZippedSource -Force -ErrorAction SilentlyContinue
			}
			
			if (Test-Path $TempSource -ErrorAction SilentlyContinue) {
				Remove-Item -Path $TempSource -Force -Recurse -ErrorAction SilentlyContinue
			}
		}
	}
	
}

#----------------------------------------------------------------------------------------

function Copy-ToRemote {
	<#
		.DESCRIPTION
			Copies input object to a remote system over an existing PSSession

		.PARAMETER remoteSession
			PSSession to copy content to

		.PARAMETER  Path
			Input content to copy
			
		.PARAMETER remotePath
			Path on remote system to copy content to
	#>
	[CmdletBinding(DefaultParameterSetName = "bySession")]
	Param (
		[Parameter(ParameterSetName = "bySession", Mandatory = $true)]
		[System.Management.Automation.Runspaces.PSSession]$remoteSession,
		
		[Parameter(ParameterSetName = "byComputerName", Mandatory = $true)]
		[string]$computerName,
		
		[Parameter(ParameterSetName = "byComputerName", Mandatory = $true)]
		[pscredential]$Credential = [pscredential]::Empty,
		
		[Parameter()]
		[string]$localPath,
		
		[Parameter()]
		[string]$remotePath
	)
	
	Begin {
	}
	
	Process {
		if ($PSCmdlet.ParameterSetName -eq "bySession") {
			Write-Log -Message "By Session"
			$tempSession = $remoteSession
		} else {
			Write-Log -Message "By Computer Name"
			$tempSession = New-PSSession -ComputerName $computerName -Credential $Credential -Authentication Credssp -EnableNetworkAccess
		}
		
		try {
			if ($debugIt) { Write-Log -Message "DEBUG > `$computerName = '$computerName'" }
			if ($debugIt) { Write-Log -Message "DEBUG > `$localPath = '$localPath'" }
			if ($debugIt) { Write-Log -Message "DEBUG > `$Credential = '$Credential'" }
			if ($debugIt) { Write-Log -Message "DEBUG > `$remotePath = '$remotePath'" }
			
			Get-ChildItem -Path $localPath | ForEach-Object {
				$localFile = $_.Fullname
				if ($debugIt) { Write-Log -Message "DEBUG > `localFile = '$localFile'" }
				$remoteFile = Join-Path -Path $remotePath -ChildPath $_.Name
				if ($debugIt) { Write-Log -Message "DEBUG > `$remoteFile = '$remoteFile'" }
				
				#Copy-ToRemoteWithChunking -Session $tempSession -localPath $localFile -remotePath $remoteFile
				Invoke-Command -ComputerName $computerName -Credential $Credential -Authentication Credssp -EnableNetworkAccess -ScriptBlock {
					#Register-PSSessionConfiguration -Name DataNoLimits
					if ($debugIt) { Write-Log -Message "DEBUG > `$args[0] = '$args[0]'" }
					if ($debugIt) { Write-Log -Message "DEBUG > `$args[1] = '$args[1]'" }
					$newPath = Split-Path $args[0] -Parent
					if ($debugIt) { Write-Log -Message "DEBUG > `$newPath = '$newPath'" }
					
					if (-not (Test-Path -Path $newPath)) {
						New-Item -ItemType Directory -Path $newPath -Force
					}
					
					[io.file]::WriteAllBytes($args[0], $args[1])
				} -ArgumentList (Join-Path -Path $remotePath -ChildPath $_.Name), (Get-Content -Encoding Byte -Path $_.Fullname -ReadCount 0)
			}
		} catch {
			Write-Log -Message "ERROR > Can't copy '$localPath' to '$Computer'!"
		}
	}
	
	End { }
}

#----------------------------------------------------------------------------------------

function Copy-ToRemoteWithChunking {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.Runspaces.PSSession]$Session,
		
		[Parameter(Mandatory = $true)]
		[System.IO.FileInfo]$localFile,
		
		[Parameter(Mandatory = $true)]
		[System.IO.DirectoryInfo]$remotePath
	)
	
	Begin { }
	
	Process {
		# Use .NET file handling for speed
		$fileContentSizeMB = [System.Math]::Round($localFile.Length / 1MB, 2)
		$fileName = Split-Path -Path $localFile.FullName -Leaf
		
		Write-Log -Message "Copying '$($localFile.Name)' from '$($localFile.Fullname)' to '$remotePath' on '$($Session.ComputerName)'..."
		Write-Log -Message "Total file size: Copying '$($localFile.Name)' from '$($localFile.Fullname)' to '$remotePath' on '$($Session.ComputerName)'..."
		
		# Open local file
		try {
			[System.IO.FileStream]$Filestream = [System.IO.File]::OpenRead($localPath)
			Write-Log -Message "Opened local file for reading"
		} catch {
			Write-Log -Message "Could not open local file '$localPath' because: '$($_.Exception.ToString())'"
			return $false
		}
		
		# Open remote file
		try {
			Invoke-Command -Session $Session -ScriptBlock {
				Param ($remFile)
				[System.IO.FileStream]$Filestream = [System.IO.File]::OpenWrite($using:remotePath)
			}
			Write-Log -Message "Opened remote file for writing"
		} catch {
			Write-Log -Message "Could not open remote file '$remotePath' because: '$($_.Exception.ToString())'"
			return $false
		}
		
		# Copy file in chunks
		$chunkSize = 1MB
		[byte[]]$contentChunk = New-Object byte[] $chunkSize
		$bytesRead = 0
		
		while (($bytesRead = $Filestream.Read($contentChunk, 0, $chunkSize)) -ne 0) {
			try {
				$Percent = $Filestream.Position / $Filestream.Length
				Write-Log -Message ("Copying {0}, {1:P2} complete, sending {2} bytes" -f $fileName, $Percent, $bytesRead)
				
				Invoke-Command -Session $Session -ScriptBlock {
					Param ($data,
						
						$bytes)
					$filestream.Write($using:contentChunk, 0, $using:bytesRead)
				}
			} catch {
				Write-Log -Message "Could not copy '$fileName' to '$($Connection.Name)'' because: '$($_.Exception.ToString())'"
				return $false
			}
		}
		
		# Close remote file
		try {
			Invoke-Command -Session $Session -ScriptBlock {
				$filestream.Close()
			}
			Write-Log -Message "Closed remote file, copy complete"
		} catch {
			Write-Log -Message "Could not close remote file '$remotePath' because: '$($_.Exception.ToString())'"
			return $false
		}
		
		# Close local file
		try {
			$Filestream.Close()
			Write-Log -Message "Closed local file, copy complete"
		} catch {
			Write-Log -Message "Could not close local file '$localPath' because: '$($_.Exception.ToString())'"
			return $false
		}
	}
	
	End { }
}

#----------------------------------------------------------------------------------------

function Scale-FileSize {
	[CmdletBinding()]
	[OutputType([string])]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0, ParameterSetName = "byFile")]
		[int64]$Length,
		
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ParameterSetName = "byNum")]
		[int64]$Size,
		
		[Parameter(Mandatory = $false)]
		[int]$Digits = 2
	)
	
	Begin {
		$scaleArray = @(@(1, 1, 1, 1KB, 1KB, 1KB, 1MB, 1MB, 1MB, 1GB, 1GB, 1GB, 1TB, 1TB, 1TB, 1PB, 1PB, 1PB), @("B", "B", "B", "KB", "KB", "KB", "MB", "MB", "MB", "GB", "GB", "GB", "TB", "TB", "TB", "PB", "PB", "PB"))
	}
	
	Process {
		if ($PSCmdlet.ParameterSetName -eq "byFile") {
			if (! $Length) {
				return "0 B"
			}
		} else {
			$Length = $Size
		}
		
		$scale = [int][math]::Log10($Length)
		"{0} $($scaleArray[1][$scale])" -f [System.Math]::Round($Length/$scaleArray[0][$scale], $Digits)
	}
	
	End { }
}

#----------------------------------------------------------------------------------------

#----------------------------------------------------------
# DO MAIN PROCESS TASKS
#----------------------------------------------------------

Write-Log -beginNewLog
$ErrorActionPreference = $saveErrorActionPreference
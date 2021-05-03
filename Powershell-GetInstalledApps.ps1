$Logfile = "logfilepath"
Function LogWrite
{
Param ([string]$logstring)
Add-content $Logfile -value $logstring
}

Function Show_ProgressBar
{
  param(
   [string]$DisplayText = "Please wait - retrieving",
   [string]$TimeinSec = 1
  )
  For($i = 1; $i -le $TimeinSec; $i++)
   {
    Write-Progress -Activity $DisplayText -PercentComplete ($i / $TimeinSec*100) # -id 1
    Start-Sleep 1
   }
}

Function Get-InstalledProgramAndUpdates {
<#
 Description
 Will retrieve the installed programs and updates 
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(ValueFromPipeline              =$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0
        )]
        [string[]]
            $ComputerName = $env:COMPUTERNAME,
        [Parameter(Position=0)]
        [string[]]
            $Property,
        [switch]
            $ExcludeSimilar,
        [int]
            $SimilarWord
    )

    begin {
        $RegistryLocation = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
                            'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
        $HashProperty = @{}
        $SelectProperty = @('ProgramName','ComputerName')
        if ($Property) {
            $SelectProperty += $Property
        }
    }

    process {
        foreach ($Computer in $ComputerName) {
            $RegBase = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$Computer)
            $RegistryLocation | ForEach-Object {
                $CurrentReg = $_
                if ($RegBase) {
                    $CurrentRegKey = $RegBase.OpenSubKey($CurrentReg)
                    if ($CurrentRegKey) {
                        $CurrentRegKey.GetSubKeyNames() | ForEach-Object {
                            if ($Property) {
                                foreach ($CurrentProperty in $Property) {
                                    $HashProperty.$CurrentProperty = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue($CurrentProperty)
                                }
                            }
                            $HashProperty.ComputerName = $Computer
                            $HashProperty.ProgramName = ($DisplayName = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue('DisplayName'))
                            if ($DisplayName) {
                                New-Object -TypeName PSCustomObject -Property $HashProperty |
                                Select-Object -Property $SelectProperty
                            } 
                        }
                    }
                }
            } | ForEach-Object -Begin {
                if ($SimilarWord) {
                    $Regex = [regex]"(^(.+?\s){$SimilarWord}).*$|(.*)"
                } else {
                    $Regex = [regex]"(^(.+?\s){3}).*$|(.*)"
                }
                [System.Collections.ArrayList]$Array = @()
            } -Process {
                if ($ExcludeSimilar) {
                    $null = $Array.Add($_)
                } else {
                    $_
                }
            } -End {
                if ($ExcludeSimilar) {
                    $Array | Select-Object -Property *,@{
                        name       = 'GroupedName'
                        expression = {
                            ($_.ProgramName -split $Regex)[1]
                        }
                    } |
                    Group-Object -Property 'GroupedName' | ForEach-Object {
                        $_.Group[0] | Select-Object -Property * -ExcludeProperty GroupedName
                    }
                }
            }
        }
    }
}
try
{
$computerSystem = Get-CimInstance CIM_ComputerSystem
<#$computerBIOS = Get-CimInstance CIM_BIOSElement#>
$computerOS = Get-CimInstance CIM_OperatingSystem
<#$computerCPU = Get-CimInstance CIM_Processor
$computerHDD = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = 'C:'"#>
$ComputerInstalledPrograms = Get-InstalledProgramAndUpdates -ExcludeSimilar -Property Publisher,InstallDate,DisplayVersion,InstallSource
$ComputerInstalledUpdates = Get-InstalledProgramAndUpdates  -Property Publisher,InstalledOn,DisplayVersion,InstallSource,IsMinorUpgrade,ReleaseType,ParentDisplayName,SystemComponent | Where-Object {[string]$_.SystemComponent -ne 1 -and ([string]$_.IsMinorUpgrade -or [string]$_.ReleaseType -or [string]$_.ParentDisplayName)} | Sort-Object ParentdisplayName, ProgramName
$ComputerInstalledUniqueUpdates = $ComputerInstalledUpdates.ProgramName | select-object -Unique
<#$ComputerHotFix = Get-CimInstance win32_quickfixengineering 

$temp = "HotFix: " + $ComputerHotFix.hotfixid + $ComputerInstalledUniqueUpdates
#$temp | Out-GridView
            
foreach ($HotFix in $ComputerHotFix)
{
  $HotFix.Description + " " +  $HotFix.HotFixID
}#>

$aResults = @()
    foreach ($InstalledPrograms in $ComputerInstalledPrograms)
    {
            IF([string]::IsNullOrEmpty($InstalledPrograms.InstallDate)) {
            $InstallDate = ""
            } else {
            $InstallDate =[DateTime]::ParseExact($InstalledPrograms.InstallDate,”yyyyMMdd”,$null).toshortdatestring()
            }

            $hItemDetails = [PSCustomObject]@{
            HostName = $computerSystem.Name
            Publisher = $InstalledPrograms.Publisher
            ProgramName = $InstalledPrograms.ProgramName
            Manufacturer=$computerSystem.Manufacturer
            InstallDate = $InstallDate
            UserloggedIn= $computerSystem.UserName
            OSVersion = $computerOS.Version
            LastReboot= $computerOS.LastBootUpTime
            }
        $aResults += $hItemDetails
    }
    
    return $aResults
}
catch
{

LogWrite -logstring $_.Exception.Message
LogWrite -logstring $_.Exception
return "Found Error"
}




# get_iis_w3p.ps1
# Check IIS App Memory

Param(
  [Parameter(
    Mandatory=$True)]
   [string]$IISVersion,
  [Parameter(
    Mandatory=$false)]
   [string]$appMemCrit,
  [Parameter(
    Mandatory=$false)]
   [string]$appMemWarn,
  [Parameter(
    Mandatory=$True)]
   [string]$outputReturn
)

$IISVersion = $IISVersion.toLower()
$appFile = "get_iis_w3p.txt"
$errorCount = 0

# Define Nagios Exit States
$stateOK = 0
$stateWarning = 1
$stateCritical = 2
$stateUnknown = 3

# Set Tresholds
$appMemMin = 0
$appMemMax = 2500
#$appMemCrit = 600000
#$appMemWarn = 300000

if ($appMemCrit -eq ""){
	$appMemCrit = 500
}

if ($appMemWarn -eq ""){
	$appMemWarn = 250
}

if ($outputReturn.toLower() -eq "file"){
	if ($IISVersion -eq "iis7"){
		$listApps = "c:\windows\system32\inetsrv\appcmd list wp"
	} else {
		$listApps = "c:\WINDOWS\system32\cscript.exe //NOlogo c:\WINDOWS\system32\iisapp.vbs"
	}
	
	# Get Application Pool Lis
	$apps = invoke-expression $listApps
	
	if ($apps -ne "Error - no results"){
	
		# Define Header Values
		$theaders = "AppId", "AppName", "AppMem", "AppCritical", "AppWarning", "AppStatus"

		# Create Table
		$table = New-Object system.Data.DataTable "Apps"
		
		foreach ($theader in $theaders){
			$col = New-Object system.Data.DataColumn $theader,([String])
			$null = $table.columns.add($col)
		}
		
		foreach ($app in $apps){
			
			$row = $table.NewRow();
			
			if ($IISVersion -eq "iis6"){
				$appName = $app.TrimStart("W3WP.exe").Split(":")[-1].TrimStart(" ")
				$appNameReplace = $appName.Replace("AppPool_","")
				$appNameReplace2 = $appNameReplace.Replace("_","")
				$appNameReplace3 = $appNameReplace2.Replace("AppPool","")
				$appName = $appNameReplace3
				$appId = $app.TrimStart("W3WP.exe").Split(":")[1].Split(" ")[1]
			} else {
				$appId = $app.TrimStart("WP `"").Split("`"")[0]
				$appName = $app.TrimEnd(")").Split(":")[1]
			}
		
			$proc = Get-Process -Id $appId
			$appMem = [Math]::Truncate($proc.get_WorkingSet64() / 1024 /1024 )
			
			$row.AppID = $appId
			$row.AppName = $appName
			$row.AppMem = $appMem
			$row.AppWarning = $appMemWarn
			$row.AppCritical = $appMemCrit
			
			if (($appMem -gt $appMemWarn) -and ($appMem -lt $appMemCrit)){
				$row.AppStatus = $stateWarning
				$errorCount = $errorCount + 1
			} elseif ($appMem -gt $appMemCrit) {
				$row.AppStatus = $stateCritical
				$errorCount = $errorCount + 1000
			} else {
				$row.AppStatus = $stateOK
			}
			$table.Rows.Add($row);
			
		}
		
		if ($errorCount -ge 1000){
			$outputMsg = $stateCritical
		} elseif ($errorCount -ge 1) {
			$outputMsg = $stateWarning
		} else {
			$outputMsg = $stateOK
		}
		$table | Export-Csv -Path $appFile -Encoding Unicode
	} else {
		$outputMsg = $stateUnknown
	}		
} elseif ($outputReturn.toLower() -eq "appmem") {
	$iisapps = Import-Csv $appFile
	$appCount = 0
	
	foreach ($iisapp in $iisapps){
		$outputMsg = $outputMsg + $iisapp.AppMem + ";"
	}

} elseif ($outputReturn.toLower() -eq "appname") {
	$iisapps = Import-Csv $appFile
	$appCount = 0
	
	foreach ($iisapp in $iisapps){
		$outputMsg = $outputMsg + $iisapp.AppName + ";"
	}
	
} else {
	# Nothing to do
}

Write-Host $outputMsg
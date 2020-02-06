# init required variabels
$sourVolPath = New-Object System.Collections.Generic.List[string]
$destVolPath="NONE"

Write-Host "Setup phase"
Write-Host "-----------"

# choose backup type
Write-Host "`nAvailable backup types:"
Write-Host "    -> 1: Entire new backup"
Write-Host "    -> 2: Update an existing backup (incremental)"
Write-Host "Which kind of backup do you want to execute (enter 1 or 2):"
$backupType = Read-Host
if (($backupType -ne "1") -and ($backupType -ne "2")) {
    Write-Host "Error: None existing backup type - exit!"
    exit
    }

# selectionbackup location
$destVolPath="NONE"
$potentialDestVol = Get-WMIObject win32_volume -Filter "DriveType='2'" | Select-Object -property Label, Name # 2 = Removable
$potentialDestVolOutput = $potentialDestVol | select -ExpandProperty Label
do{
    Write-Host "`nDetected Volumes:"
    $_=1
    for ($i=0; $i -lt $potentialDestVolOutput.length; $i++){
        Write-Host "    ->"$_ $potentialDestVolOutput[$i]
        $_++
        }
    $destVolName = Read-Host "Enter your destination volume (name)"
    $potentialDestVol | % { if( $_.Label -ceq $destVolName){$destVolPath=$_.Name} # % = foreach; -ceq -> case sensitive
    }
} while ($destVolPath -eq "NONE")

# add the folders which need to be backed up to list
do{
   $path = Read-Host -prompt "`nEnter path of folder to be backed up (d for done)"
   $addOrNot = checkIfPathExist($path)
   if ($addOrNot) {
        $sourVolPath.Add($path)
   }elseif ($path -eq "d") {
        continue
   }Else {
        Write-Host "'$path' is not an existing directory!"
   }
} while (!($path -eq "d"))

# check if variable is a existing path
function checkIfPathExist($path) { # error - when pressing enter
    $addOrNot = Test-Path -Path $path
    return $addOrNot
}

# confirmation
Write-Host "`nConfirmation"
Write-Host "-------------"
Write-Host "`nSelected Backup type:"
switch ($backupType){
1 {"    -> New Backup"}
2 {"    -> Incremental Backup"}
}
Write-Host "`nThe following folders are going to be backed up:"
for ($i=0; $i -lt $sourVolPath.Count; $i++){
    Write-Host "    ->"$sourVolPath[$i]
}
Write-Host "`nSelected destination Volume:"
Write-Host "    ->" $destVolPath
$confirmation = Read-Host -Prompt "`nWrite 'Yes' to confirm or 'no' to cancel"
if ($confirmation -ceq "Yes") {
    continue
}Else {
    Write-Host "`nCanceled!"
}

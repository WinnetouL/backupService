# init required variabels
$sourFilePath = New-Object System.Collections.Generic.List[string]
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

# selection of backup location
$potentialDestVol = Get-WMIObject win32_volume -Filter "DriveType='2'" | Select-Object -property Label, Name # 2 = Removable
$potentialDestVolOutput = @($potentialDestVol | select -ExpandProperty Label) # force to return an System.Object (array)
do{
    Write-Host "`nDetected Volumes:"
    $_=1
    for ($i=0; $i -lt $potentialDestVolOutput.length; $i++){
        Write-Host "    ->"$_ $potentialDestVolOutput[$i]
        $_++
        }
    $destVolName = Read-Host "Enter your destination volume (name)"
    $potentialDestVol | % {if( $_.Label -ceq $destVolName){$destVolPath=$_.Name} # % = foreach; -ceq -> case sensitive
    }
} while ($destVolPath -eq "NONE")

# add the folders which need to be backed up to list
do{
   $path = Read-Host -prompt "`nEnter path of folder to be backed up (d for done)"
   $addOrNot = checkIfPathExist($path)
   if ($addOrNot) {
        $sourFilePath.Add($path)
   }elseif ($path -eq "d") {
        continue
   }Else {
        Write-Host "'$path' is not an existing directory!"
   }
} while (!($path -eq "d"))

# confirmation
Write-Host "`nConfirmation"
Write-Host "-------------"
Write-Host "`nSelected Backup type:"
switch ($backupType){
1 {"    -> New Backup"}
2 {"    -> Incremental Backup"}
}
Write-Host "`nThe following folders are going to be backed up:"
for ($i=0; $i -lt $sourFilePath.Count; $i++){
    Write-Host "    ->"$sourFilePath[$i]
}
Write-Host "`nSelected destination Volume:"
Write-Host "    ->" $destVolPath
$confirmation = Read-Host -Prompt "`nWrite 'Yes' to confirm or 'no' to cancel"
if (!($confirmation -ceq "Yes")) {
    Write-Host "`nCanceled!"
    exit 
}

# create an backup environment
$destVolPath += "BackupEnv\"
if (!(checkIfPathExist($destVolPath))) {
    makeDir($destVolPath)
    Write-Host "Backup Environment created at:" $destVolPath
}

$itemsBackupEnv = Get-ChildItem -Path $destVolPath -Attributes Directory
$backupNames = highestNumDirName($itemsBackupEnv)
if ($backupType -eq "1") {
    # Write-Host "1 ---" $backupNames[0]
    makeDir($backupNames[0])
}elseif ($backupType -eq "2") {
    # get list of subdirs
    $listOfSourDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $sourFilePath.Count; $i++){
        Get-ChildItem -Path $sourFilePath[$i] -Recurse -Force -Attributes Directory | % {$listOfSourDir.Add($_.FullName)} # D:\
        }
    foreach ($dir in $listOfSourDir) {
        Write-Host $dir
    }
    for ($i=0; $i -lt $listOfSourDir.Count; $i++){
        if (!(checkIfPathExist($listOfSourDir[$i]))) {
            makeDir($listOfSourDir[$i])
            $_++; Write-Host $_ "-" $listOfSourDir[$i]
            }Else {
                Write-Host "nothing created!"
                }
        }
    }

# check if variable is a existing path
function checkIfPathExist($path) { # error - when pressing enter
    $addOrNot = Test-Path -Path $path
    return $addOrNot
}

# returns an array with the required paths
function highestNumDirName($itemList) { # error - when pressing enter
    $backupNames = New-Object System.Collections.ArrayList
    $highestNumBackup = 0
    for ($i=0; $i -lt $itemList.length; $i++){
        if ($highestNumBackup -lt ($itemList[$i].Name -as [int])) {
            $highestNumBackup = $itemList[$i].Name -as [int]
            }
        $secHighestPathBackup = $itemList[$i].FullName # better choose modification date 
        }
    $firstHighestNumBackup = $highestNumBackup + 1 | % {"{0:d3}" -f $_}
    $firstHighestPathBackup = $destVolPath + $firstHighestNumBackup # Join-Path?
    $backupNames += $firsthighestPathBackup
    $backupNames += $secHighestPathBackup
    return $backupNames
    }

# create directories silently
function makeDir($path) { # error - when pressing enter
    mkdir $path | Out-Null # "> $null" would be much faster
}



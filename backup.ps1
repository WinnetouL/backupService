﻿. "$PSScriptRoot\funcOfBackupSer.ps1"

Write-Host "Setup phase"
Write-Host "-----------"

# choose Backup Type
Write-Host "`nAvailable Backup Types:"
Write-Host "`t-> 1: Entire new Backup"
Write-Host "`t-> 2: Update an existing Backup (incremental)"
$backupType = Read-Host "Which kind of Backup do you want to execute (enter 1 or 2)"
if (($backupType -ne "1") -and ($backupType -ne "2")) {
    Write-Host "`tError: None existing Backup Type!"
    Write-Host "`tExit!"
    exit
    }

# selection of Backup location
$destQualifier="None"
$availableVol = Get-WMIObject win32_volume -Filter "DriveType='2'" # 2 = Removable
if (!$availableVol){
    Write-Host "`tError: No Volumes avaiable!"
    Write-Host "`tExit"
    exit
    }
do{
    Write-Host "`nDetected Volumes:"
    foreach($volume in $availableVol){
        Write-Host "`t->"$volume.Label "("$volume.Name")"
        }
    $destVolName = Read-Host "Enter your destination volume (name)"
    $availableVol | ForEach-Object {if( $_.Label -ceq $destVolName){$destQualifier=$_.Name}}
} while ($destQualifier -ceq "None")

# add the folders which need to be backed up to list
$sourFilePath = New-Object System.Collections.Generic.List[string]
do{
    $path = Read-Host -prompt "`nEnter path of folder to be backed up (d for done)"
    $addOrNot = checkPathExist $path
    if ($addOrNot) {
        $sourFilePath.Add($path)
        }
    elseif ($path -eq "d") {
        continue
        }
    Else {
        Write-Host "`t->'$path' is not an existing directory!"
    }
} while (!($path -eq "d"))
if (!$sourFilePath){
    Write-Host "`tError: No Path entered!"
    Write-Host "`tExit"
    exit
    }

# confirmation
Write-Host "`nConfirmation"
Write-Host "-------------"
Write-Host "`nSelected Backup Type:"
switch ($backupType){
    1 {"`t-> New Backup"}
    2 {"`t-> Incremental Backup"}
    }
Write-Host "`nThe following folders are going to be backed up:"
for ($i=0; $i -lt $sourFilePath.Count; $i++){
    Write-Host "`t->"$sourFilePath[$i]
    }
Write-Host "`nSelected destination Volume:"
Write-Host "`t->" $destVolName
$confirm = Read-Host -Prompt "`nWrite 'Yes' to confirm or 'no' to cancel"
if (!($confirm -ceq "Yes")) {
    Write-Host "`tCanceled!"
    exit 
    }

# create an Backup environment
$envPath = Join-Path -Path $destQualifier -ChildPath "BackupEnv"
if (!(checkPathExist $envPath)) {
    makeDir $envPath
    Write-Host "`t-> Backup Environment created at:" $envPath
    }
$subDirsEnv = Get-ChildItem -Path $envPath -Attributes D
$backupName = getBackupName $subDirsEnv $envPath $backupType
if ($backupType -eq "1") {
    makeDir $backupName
    Write-Host "`nCopied Directories:"
    for ($i=0; $i -lt $sourFilePath.Count; $i++){
        Write-Host $i "`t-> --Copy--" $sourFilePath[$i]
        $parent = Split-Path -Path $sourFilePath[$i] -Leaf
        $destFilePath = Join-Path -Path $backupName -ChildPath $parent
        copyFile $sourFilePath[$i] $destFilePath $backupType
        }
    Write-Host "`nNew Backup at: " $backupName
    }
elseif ($backupType -eq "2") {

    # get a list of all subdirectories at source and a list of corresponding path trailers
    $allDirSour = New-Object System.Collections.Generic.List[string]
    $trailer = New-Object System.Collections.Generic.List[string]
    $onetimeSubSourDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $sourFilePath.Count; $i++){
        Get-ChildItem -Path $sourFilePath[$i] -Recurse -Force -Attributes D | ForEach-Object {$onetimeSubSourDir.Add($_.FullName); $allDirSour.Add($_.FullName)} # two lists of all subdir; don't add NULL values in case of error (UnauthorizedAccessException)
        $parent = Split-Path -Path $sourFilePath[$i] -Parent
        for ($ii=0; $ii -lt $onetimeSubSourDir.Count; $ii++){
            $onetimeSubSourDir[$ii] -replace [regex]::escape($parent)  | ForEach-Object {$trailer.Add($_)} # replace with nothing to get just the expected ending
            }
        $onetimeSubSourDir.Clear()
        }

    # generate a list with the all full paths for the backup out of trailer and the corresponding backup
    $futureDestDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $trailer.Count; $i++){
        $path = Join-Path -Path $backupName -ChildPath $trailer[$i]
        $futureDestDir.Add($path)
        }

    # add also the the full path for the future parent paths, due they aren't included in the trailer list and therefore
    for ($i=0; $i -lt $sourFilePath.Count; $i++){
        $parent = Split-Path -Path $sourFilePath[$i] -Leaf
        $path = Join-Path -Path $backupName -ChildPath $parent
        $futureDestDir.Add($path)
        $allDirSour.Add($sourFilePath[$i])
        }
    $currSubDirDest = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -Path $backupName -Recurse -Force -Attributes D | ForEach-Object {$currSubDirDest.Add($_.FullName)} # get a list of the dir which already exist, to be able to determine which dirs can be deleted

    # create a list of dir to remove which exist in the dest Backup, but are not part of the directories which needs to be backed up
    $rmDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $currSubDirDest.Count; $i++){
        if (!($futureDestDir.Contains($currSubDirDest[$i]))) {
            $rmDir.Add($currSubDirDest[$i])
            }
        }

    # remove dir at destination if not required by selection
    Write-Host "`nFolder synchronization:"
    $rmDir = $rmDir | Sort-Object {($_.ToCharArray() | Where-Object{$_ -eq "\"} | Measure-Object).count} -Descending # sort dir by depth in order to have no issues at removal
    foreach ($dir in $rmDir) {removeDir $dir}

    # create subdir at destination location if it doesn't exist
    for ($i=0; $i -lt $futureDestDir.Count; $i++){
        if (!(checkPathExist $futureDestDir[$i])) {
            makeDir $futureDestDir[$i]
            $_++; Write-Host $_ "`t-> --Created--" $futureDestDir[$i]
            }
        Else {
            Write-Host "`t-> Already exists:" $futureDestDir[$i]
            }
        }

    # get list of files to remove
    $rmFiles = getFileDiff $futureDestDir $allDirSour 1

    # get list of files to copy
    $cpFiles = getFileDiff $allDirSour $futureDestDir 2
    
    # File synchronization (remove and copy files)
    Write-Host "`nFile synchronization:"
    for ($i=0; $i -lt $rmFiles.Count; $i++){
        Write-Host "`t-> --Remove--" $rmFiles[$i]
        removeFile $rmFiles[$i]
        }
    for ($i=0; $i -lt $cpFiles.Count; $i+=2){
        Write-Host "`t-> --Copied--" $cpFiles[$i+1]
        copyFile $cpFiles[$i] $cpFiles[$i+1] $backupType
        }
    Write-Host "`nUpdated the following Backup:"
    Write-Host "`t->" $backupName
    }

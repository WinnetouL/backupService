. "$PSScriptRoot\funcOfBackupSer.ps1"

# init required variabels
$sourFilePath = New-Object System.Collections.Generic.List[string]
$destVolPath="NONE"
Write-Host "Setup phase"
Write-Host "-----------"

# choose backup type
Write-Host "`nAvailable backup types:"
Write-Host "    -> 1: Entire new backup"
Write-Host "    -> 2: Update an existing backup (incremental)"
$backupType = Read-Host "Which kind of backup do you want to execute (enter 1 or 2)"
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
   $addOrNot = checkIfPathExist $path
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
$destVolPath += "BackupEnv"
if (!(checkIfPathExist $destVolPath)) {
    makeDir $destVolPath
    Write-Host "Backup Environment created at:" $destVolPath
}
$itemsBackupEnv = Get-ChildItem -Path $destVolPath -Attributes Directory
$backupNames = highestNumDirName $itemsBackupEnv
$backupNames = [System.Collections.Generic.List[string]]@($backupNames) # object(array) -> list(object)

if ($backupType -eq "1") {
    makeDir $backupNames[0]
    Write-Host "`nCopied Directories:"
    for ($i=0; $i -lt $sourFilePath.Count; $i++){
        Write-host $i "--Copy--" $sourFilePath[$i]
        copyFile $sourFilePath[$i] $backupNames[0] $backupType
    }
    Write-Host "`nNew Backup at: " $backupNames[0]
}elseif ($backupType -eq "2") {

    # get a list of subdirs at destination
    $backupNames.RemoveAt(0) # QuickFix: need to adjust the list due I want just a specific path for next step and my function doesn't work with '$backupNames[1]'
    $listExistDestDir = genListSubDir $backupNames # get a list of the dir which already exist, to be able to determine which dirs can be deleted
    
    # get list of subdirs at source
    $listOfSourDir = genListSubDir $sourFilePath
    
    # generate a list out of the subdirs but for destination location
    $listOfDestDir = New-Object System.Collections.Generic.List[string]
    $listOfSourQualifier = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $listOfSourDir.Count; $i++){
        Split-Path -Path $listOfSourDir[$i] -Qualifier | % {if ($listOfSourQualifier -notcontains $_) {$listOfSourQualifier.Add($_)}} # need it later for building paths and check them (removal part)
        Split-Path -Path $listOfSourDir[$i] -NoQualifier | % {Join-Path -Path $backupNames[0] -ChildPath $_} | % {$listOfDestDir.Add($_)} # '$backupNames[0]' due the quick fix line 88
        }
    
    # create a list of dir which potentially need to be removed before copy process starts
    $listPotentialRmDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $listExistDestDir.Count; $i++){
        $itemPotentialRmDir = foreach ($qualifier in $listOfSourQualifier) {$listExistDestDir[$i].Replace($backupNames[0], $qualifier)}
        $listPotentialRmDir.Add($itemPotentialRmDir)
    }
    
    # create a list of dir to remove which exist in the dest backup, but are not part of the dir which needs to be back upped
    $listRmDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $listPotentialRmDir.Count; $i++){
        if (!(checkIfPathExist $listPotentialRmDir[$i])) {
            $itemRmDir = foreach ($qualifier in $listOfSourQualifier) {$listPotentialRmDir[$i].Replace($qualifier, $backupNames[0])}
            $listRmDir.Add($itemRmDir)
            Write-Host "Will be removed:" $itemRmDir
            }
        }
    
    # remove dir at destination if not required by selection
    $listRmDir = $listRmDir | sort {($_.ToCharArray() | ?{$_ -eq "\"} | measure).count} -Descending # sort dir by depth in order to have no issues at removal
    foreach ($dir in $listRmDir) {removeDir $dir}
    
    # create subdir at destination location if it doesn't exist
    Write-Host "`nFolder synchronization:"
    for ($i=0; $i -lt $listOfDestDir.Count; $i++){
        if (!(checkIfPathExist $listOfDestDir[$i])) {
            makeDir $listOfDestDir[$i]
            $_++; Write-Host $_ "created:" $listOfDestDir[$i]
            }Else {
                Write-Host "Already exists:" $listOfDestDir[$i]
            }
        }

    # get list of files to remove
    $filesToRemove = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $listOfDestDir.Count; $i++){
        $listOfSourDirHash = calcHash $listOfSourDir[$i]
        $listOfDestDirHash = calcHash $listOfDestDir[$i]
        for ($ii=1; $ii -lt $listOfDestDirHash.Count; $ii+=2){
            if ($listOfSourDirHash) {
                if (!($listOfSourDirHash.Contains($listOfDestDirHash[$ii]))) {
                    $filesToRemove.Add($listOfDestDirHash[$ii-1])
                    }
                }
                Else{
                    $filesToRemove.Add($listOfDestDirHash[$ii-1])
                    }
          
            }
    }

    # get list of files to copy
    $filesToCopy = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $listOfSourDir.Count; $i++){
        $listOfSourDirHash = calcHash $listOfSourDir[$i]
        $listOfDestDirHash = calcHash $listOfDestDir[$i]
        for ($ii=1; $ii -lt $listOfSourDirHash.Count; $ii+=2){
            if ($listOfDestDirHash) {
                if (!($listOfDestDirHash.Contains($listOfSourDirHash[$ii]))) {
                    $filesToCopy.Add($listOfSourDirHash[$ii-1])
                    }
                }
                Else{
                    $filesToCopy.Add($listOfSourDirHash[$ii-1])
                    }
          
            }
    }
    # File synchronization (remove and copy files)
    Write-Host "`nFile synchronization:"
    for ($i=0; $i -lt $filesToRemove.Count; $i++){
        Write-host $i "--Remove--" $filesToRemove[$i]
        removeFile $filesToRemove[$i] $backupNames[0]
        }
    for ($i=0; $i -lt $filesToCopy.Count; $i++){
        Write-host $i "--Copy--" $filesToCopy[$i]
        copyFile $filesToCopy[$i] $backupNames[0] $backupType
        }
    Write-Host "`nUpdated the following Backup: " $backupNames[0]
    }

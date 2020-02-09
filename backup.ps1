# check if variable is a existing path
function checkIfPathExist($path) { # error - when pressing enter
    $addOrNot = Test-Path -Path $path
    return $addOrNot
    }
# returns an array with the required paths
function highestNumDirName($itemList) {
    $backupNames = New-Object System.Collections.Generic.List[string]
    $highestNumBackup = 0
    for ($i=0; $i -lt $itemList.length; $i++){
        if ($highestNumBackup -lt ($itemList[$i].Name -as [int])) {
            $highestNumBackup = $itemList[$i].Name -as [int]
            }
        $secHighestPathBackup = $itemList[$i].FullName # better choose modification date 
        }
    $firstHighestNumBackup = $highestNumBackup + 1 | % {"{0:d3}" -f $_}
    $firstHighestPathBackup = Join-Path -Path $destVolPath -ChildPath $firstHighestNumBackup
    $backupNames += $firsthighestPathBackup
    $backupNames += $secHighestPathBackup
    return $backupNames
    }
# create directories silently
function makeDir($path) {
    New-Item -Path $path -type Directory | Out-Null # "> $null" would be much faster
    }
# remove directories silently
function removeDir($path) {
    Remove-Item -path $path -Recurse -Force
    }
# returns a list of all childpathes of directories inside a parent path
function genListSubDir($sourPath) {
    $listOfDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $sourPath.Count; $i++){
        Get-ChildItem -Path $sourPath[$i] -Recurse -Force -Attributes Directory | % {$listOfDir.Add($_.FullName)}
        }
    return $listOfDir
    }
# returns a list wish hash and filenames
function calcHash($path) {
    $hashList = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -Path $path -Force | % {$hashList.Add($_.FullName); Get-FileHash $_.FullName -Algorithm SHA1} | % {$hashList.Add($_.Hash)}
    return $hashList
    }

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
    Write-Host "1 ---" $backupNames[0]
    makeDir $backupNames[0]
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
        Split-Path -Path $listOfSourDir[$i] -NoQualifier | % {Join-Path -Path $backupNames[0] -ChildPath $_} | % {$listOfDestDir.Add($_)} # '$backupNames[0]' due the quick fix line 124
        }
    
    # create a list of dir which potentially need to be removed before copy process starts
    $listPotentialRmDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $listExistDestDir.Count; $i++){
        $itemPotentialRmDir = foreach ($qualifier in $listOfSourQualifier) {$listExistDestDir[$i].Replace($backupNames[0], $qualifier)}
        $listPotentialRmDir.Add($itemPotentialRmDir)
    }
    
    # remove dir which exist in the dest backup, but are not part of the dir which needs to be back upped
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
    for ($i=0; $i -lt $listOfDestDir.Count; $i++){
        if (!(checkIfPathExist $listOfDestDir[$i])) {
            makeDir $listOfDestDir[$i]
            $_++; Write-Host $_ "created:" $listOfDestDir[$i]
            }Else {
                Write-Host "Nothing Created!"
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
     for ($i=0; $i -lt $filesToCopy.Count; $i++){
        Write-host $i "--Copy--" $filesToCopy[$i]
        }
  }

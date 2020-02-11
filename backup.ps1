. "$PSScriptRoot\funcOfBackupSer.ps1"

Write-Host "Setup phase"
Write-Host "-----------"

# choose Backup Type
Write-Host "`nAvailable Backup Types:"
Write-Host "    -> 1: Entire new Backup"
Write-Host "    -> 2: Update an existing Backup (incremental)"
$backupType = Read-Host "Which kind of Backup do you want to execute (enter 1 or 2)"
if (($backupType -ne "1") -and ($backupType -ne "2")) {
    Write-Host "Error: None existing Backup Type - exit!"
    exit
    }

# selection of Backup location
$destQualifier="None"
$availableVol = Get-WMIObject win32_volume -Filter "DriveType='2'" | Select-Object -property Label, Name # 2 = Removable
do{
    Write-Host "`nDetected Volumes:"
    for ($i=0; $i -lt $availableVol.length; $i++){
        Write-Host "    ->"$availableVol[$i].Label "("$availableVol[$i].Name")"
        }
    $destVolName = Read-Host "Enter your destination volume (name)"
    $availableVol | % {if( $_.Label -ceq $destVolName){$destQualifier=$_.Name}} # % = foreach; -ceq -> case sensitive
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
        Write-Host "'$path' is not an existing directory!"
    }
} while (!($path -eq "d"))

# confirmation
Write-Host "`nConfirmation"
Write-Host "-------------"
Write-Host "`nSelected Backup Type:"
switch ($backupType){
    1 {"    -> New Backup"}
    2 {"    -> Incremental Backup"}
    }
Write-Host "`nThe following folders are going to be backed up:"
for ($i=0; $i -lt $sourFilePath.Count; $i++){
    Write-Host "    ->"$sourFilePath[$i]
    }
Write-Host "`nSelected destination Volume:"
Write-Host "    ->" $destVolName
$confirm = Read-Host -Prompt "`nWrite 'Yes' to confirm or 'no' to cancel"
if (!($confirm -ceq "Yes")) {
    Write-Host "`nCanceled!"
    exit 
    }

# create an Backup environment
$envPath = Join-Path -Path $destQualifier -ChildPath "BackupEnv"
if (!(checkPathExist $envPath)) {
    makeDir $envPath
    Write-Host "    -> Backup Environment created at:" $envPath
    }
$subDirsEnv = Get-ChildItem -Path $envPath -Attributes Directory
$backupNames = highestNumDirName $subDirsEnv $envPath
$backupNames = [System.Collections.Generic.List[string]]@($backupNames) # object(array) -> list(object)

if ($backupType -eq "1") {
    makeDir $backupNames[0]
    Write-Host "`nCopied Directories:"
    for ($i=0; $i -lt $sourFilePath.Count; $i++){
        Write-host $i "    -> --Copy--" $sourFilePath[$i]
        copyFile $sourFilePath[$i] $backupNames[0] $backupType
        }
    Write-Host "`nNew Backup at: " $backupNames[0]
    }
elseif ($backupType -eq "2") {

    # get a list of subdirs at destination
    $backupNames.RemoveAt(0) # QuickFix: need to adjust the list due I want just a specific path for next step and my function doesn't work with '$backupNames[1]'
    $currSubDestDir = genListSubDir $backupNames # get a list of the dir which already exist, to be able to determine which dirs can be deleted

    # get list of subdirs at source
    $subSourDir = genListSubDir $sourFilePath

    # generate a list out of the subdirs but for destination location
    $futureDestDir = New-Object System.Collections.Generic.List[string]
    $sourQualifier = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $subSourDir.Count; $i++){
        Split-Path -Path $subSourDir[$i] -Qualifier | % {if ($sourQualifier -notcontains $_) {$sourQualifier.Add($_)}} # need it later for building paths and check them (removal part)
        Split-Path -Path $subSourDir[$i] -NoQualifier | % {Join-Path -Path $backupNames[0] -ChildPath $_} | % {$futureDestDir.Add($_)} # '$backupNames[0]' due the quick fix line 86
        }

    # create a list of dir which potentially need to be removed before copy process starts
    $potentialRmDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $currSubDestDir.Count; $i++){
        $itemPotentialRmDir = foreach ($qualifier in $sourQualifier) {$currSubDestDir[$i].Replace($backupNames[0], $qualifier)}
        $potentialRmDir.Add($itemPotentialRmDir)
        }

    # create a list of dir to remove which exist in the dest Backup, but are not part of the dir which needs to be backed up
    $rmDir = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $potentialRmDir.Count; $i++){
        if (!(checkPathExist $potentialRmDir[$i])) {
            $itemRmDir = foreach ($qualifier in $sourQualifier) {$potentialRmDir[$i].Replace($qualifier, $backupNames[0])}
            $rmDir.Add($itemRmDir)
            }
        }

    # remove dir at destination if not required by selection
    Write-Host "`nFolder synchronization:"
    $rmDir = $rmDir | sort {($_.ToCharArray() | ?{$_ -eq "\"} | measure).count} -Descending # sort dir by depth in order to have no issues at removal
    foreach ($dir in $rmDir) {removeDir $dir}
    
    # create subdir at destination location if it doesn't exist
    for ($i=0; $i -lt $futureDestDir.Count; $i++){
        if (!(checkPathExist $futureDestDir[$i])) {
            makeDir $futureDestDir[$i]
            $_++; Write-Host $_ "    -> --Created--" $futureDestDir[$i]
            }
            Else {
                Write-Host "    -> Already exists:" $futureDestDir[$i]
                }
        }

    # get list of files to remove
    $rmFiles = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $futureDestDir.Count; $i++){
        $subSourDirHash = calcHash $subSourDir[$i]
        $futureDestDirHash = calcHash $futureDestDir[$i]
        for ($ii=1; $ii -lt $futureDestDirHash.Count; $ii+=2){
            if ($subSourDirHash) {
                if (!($subSourDirHash.Contains($futureDestDirHash[$ii]))) {
                    $rmFiles.Add($futureDestDirHash[$ii-1])
                    }
                }
                Else{
                    $rmFiles.Add($futureDestDirHash[$ii-1])
                    }
            }
        }

    # get list of files to copy
    $filesToCopy = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $subSourDir.Count; $i++){
        $subSourDirHash = calcHash $subSourDir[$i]
        $futureDestDirHash = calcHash $futureDestDir[$i]
        for ($ii=1; $ii -lt $subSourDirHash.Count; $ii+=2){
            if ($futureDestDirHash) {
                if (!($futureDestDirHash.Contains($subSourDirHash[$ii]))) {
                    $filesToCopy.Add($subSourDirHash[$ii-1])
                    }
                }
                Else{
                    $filesToCopy.Add($subSourDirHash[$ii-1])
                    }
            }
        }

    # File synchronization (remove and copy files)
    Write-Host "`nFile synchronization:"
    for ($i=0; $i -lt $rmFiles.Count; $i++){
        Write-host $i "    -> --Remove--" $rmFiles[$i]
        removeFile $rmFiles[$i]
        }
    for ($i=0; $i -lt $filesToCopy.Count; $i++){
        Write-host $i "    -> --Copy--" $filesToCopy[$i]
        copyFile $filesToCopy[$i] $backupNames[0] $backupType
        }
    Write-Host "`nUpdated the following Backup: " $backupNames[0]
    }

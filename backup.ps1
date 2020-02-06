# init required variabels
$saveFolder = New-Object System.Collections.Generic.List[string]
$destVolPath="NONE"


Write-Host "Setup phase"
Write-Host "-----------"

# choose backup type
Write-Host "Available backup types:"
Write-Host "    1: Entire new backup"
Write-Host "    2: Update an existing backup (incremental)"
$backupType = Read-Host "Which kind of backup do you want to execute (enter 1 or 2)"

# backup location
$possibleDestVolumes = Get-WMIObject win32_volume | Select-Object -property Label, Name # 2 = Removable -Filter "DriveType='2'"
$possibleDestVolumesOut = $possibleDestVolumes | select -ExpandProperty Label
$_=1
for ($i=0; $i -lt $possibleDestVolumesOut.length; $i++){
    Write-Host $_ "-" $possibleDestVolumesOut[$i]
    $_++
}
$destVolName = Read-Host "Enter your destination volume "
$possibleDestVolumes | % { if( $_.Label -ceq $destVolName){$destVolPath=$_.Name}} # % = foreach; -ceq -> case sensitive

# add the folders which need to be backed up to list
do{
   $path = Read-Host -prompt "Enter path of folder to be backed up or hit q to quit"
   $addOrNot = checkIfPathExist($path)
   if ($addOrNot) {
        $saveFolder.Add($path)
   }elseif ($path -eq "q") {
        continue
   }Else {
        Write-Host "'$path' is not an existing directory!"
   }
} while (!($path -eq "q"))

# check if variable is a existing path
function checkIfPathExist($path) {
    $addOrNot = Test-Path -Path $path
    return $addOrNot
}

# confirmation
Write-Host "Selected backup type:"
switch ($backupType){
1 {"    -> Backup Type - New backup"}
2 {"    -> Backup Type - Incremental Backup"}
default {"    Error: None existing backup type - exit!"; exit}
}
Write-Host "The following folders are going to be backed up:"
for ($i=0; $i -lt $saveFolder.length; $i++){
    Write-Host "    -> $saveFolder[$i]"
}
Write-Host "Selected Volume:"
Write-Host "    ->" $destVolPath

$confirmation = Read-Host -Prompt "Write 'Yes' to confirm or 'no' to cancel"
if ($confirmation -ceq "Yes") {
    continue
}Else {
    Write-Host "    -> Canceled!"
}













#    Write-Host $updateType.GetType()
# init required variabels
$saveFolder = New-Object System.Collections.Generic.List[string]
$destVolPath="NONE"


Write-Host "Setup phase"
Write-Host "-----------"

# choose backup type
Write-Host "Which kind of backup do you want to execute (enter 1 or 2)"
Write-Host "1: Entire new backup"
Write-Host "2: Update an existing backup (incremental)"
$backupType = Read-Host

# backup location
$possibleDestVolumes += Get-WMIObject win32_volume -Filter "DriveType='2'" | Select-Object -property Label, Name # 2 = Removable
Write-Host $possibleDestVolumes.Label
$destVolName = Read-Host "Enter your destination volume "
$a | % { if( $_.Label -ceq $destVolName){$destVolPath=$_.Name}} # % = foreach; -ceq -> case sensitive
Write-Host $destVolPath





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

Write-Host "The following folders are going to be backed up:"
for ($i=0; $i -lt $saveFolder.length; $i++){
    Write-Host "- $saveFolder[$i]"
}
$confirmation = Read-Host -Prompt "Hit 'y' to continue"
if ($confirmation -eq "y") {
    continue
}Else {
    Write-Host ""
}













#    Write-Host $updateType.GetType()
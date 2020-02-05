Write-Host "Setup phase"
Write-Host "-----------"

do{
    Write-Host "Which kind of backup do you want to execute (enter 1 or 2)"
    Write-Host "1: Entire new backup"
    Write-Host "2: Update an existing backup (incremental)"
    $updateType = Read-Host
} while (($updateType -eq "1") -or ($updateType -eq "2"))


Switch($Eingabe) {
    0{$Detail = 'Die Variable ist 0'}
    1{$Detail = 'Die Variable ist 1'}
    2{$Detail = 'Die Variable ist 2'}
    3{$Detail = 'Die Variable ist 3'}
    4{$Detail = 'Die Variable ist 4'}
}
$Detail
# init required variabels
$saveFolder = New-Object System.Collections.Generic.List[string]
$destinationFolder

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
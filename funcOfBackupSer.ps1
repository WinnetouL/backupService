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

# copy files
function copyFile($sourcePath, $backupQualifier, $backupType) {
    if ($backupType -eq "1") {
        $destPath = Split-Path -Path $sourcePath -NoQualifier | % {Join-Path -Path $backupQualifier -ChildPath $_}
        Copy-Item -Path $sourcePath -Destination $destPath -Force -Recurse
    }elseif ($backupType -eq "2") {
        $destPath = Split-Path -Path $sourcePath -NoQualifier | % {Join-Path -Path $backupQualifier -ChildPath $_}
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        }
    }

# remove files
function removeFile($destPath, $backupQualifier) {
    Remove-Item -Path $destPath -Force
    }

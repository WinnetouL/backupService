# check if variable is a existing path
function checkPathExist($path) {
    $addOrNot = Test-Path -Path $path
    return $addOrNot
    }

# returns an array with the required paths
function highestNumDirName($itemList, $envPath) {
    $backupNames = New-Object System.Collections.Generic.List[string]
    $highestNum = 0
    for ($i=0; $i -lt $itemList.length; $i++){
        if ($highestNum -lt ($itemList[$i].Name -as [int])) {
            $highestNum = $itemList[$i].Name -as [int]
            }
        $secHighestPath = $itemList[$i].FullName # better choose modification date 
        }
    $firstHighestNum = $highestNum + 1 | % {"{0:d3}" -f $_}
    $firstHighestPath = Join-Path -Path $envPath -ChildPath $firstHighestNum
    $backupNames += $firsthighestPath
    $backupNames += $secHighestPath
    return $backupNames
    }

# create directories silently
function makeDir($path) {
    New-Item -Path $path -type Directory | Out-Null # "> $null" would be much faster
    }

# remove directories silently
function removeDir($path) {
    Write-Host "`t-> --Remove--" $path
    Remove-Item -path $path -Recurse -Force
    }

# returns a list of all childpathes of directories inside a parent path
function genListSubDir($sourPath) {
    $dirs = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $sourPath.Count; $i++){
        Get-ChildItem -Path $sourPath[$i] -Recurse -Force -Attributes Directory | % {$dirs.Add($_.FullName)}
        }
    return $dirs
    }

# returns a list wish hash and filenames
function calcHash($path) {
    $hashes = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -Path $path -Force -Attributes !D | % {$hashes.Add($_.FullName); Get-FileHash $_.FullName -Algorithm SHA1} | % {$hashes.Add($_.Hash)}
    return $hashes
    }

# copy files
function copyFile($sourcePath, $backupQualifier, $backupType) {
    if ($backupType -eq "1") {
        $destPath = Split-Path -Path $sourcePath -NoQualifier | % {Join-Path -Path $backupQualifier -ChildPath $_}
        Copy-Item -Path $sourcePath -Destination $destPath -Force -Recurse
    }
    elseif ($backupType -eq "2") {
        $destPath = Split-Path -Path $sourcePath -NoQualifier | % {Join-Path -Path $backupQualifier -ChildPath $_}
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        }
    }

# remove files
function removeFile($destPath) {
    Remove-Item -Path $destPath -Force
    }

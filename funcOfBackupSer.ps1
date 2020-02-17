# check if variable is a existing path
function checkPathExist($path) {
    $addOrNot = Test-Path -Path $path
    return $addOrNot
    }

# returns a string with the corresponding backup path
function getBackupName($itemList, $envPath, $backupType) {
    $highestNum = 0
    for ($i=0; $i -lt $itemList.length; $i++){
        if ($highestNum -lt ($itemList[$i].Name -as [int])) {
            $highestNum = $itemList[$i].Name -as [int]
            }
        $highestNumPath = $itemList[$i].FullName # better choose modification date 
        }
    if ($backupType -eq "1") {
        $newHighestNum = $highestNum + 1 | ForEach-Object {"{0:d3}" -f $_}
        $newHighestNumPath = Join-Path -Path $envPath -ChildPath $newHighestNum
        return $newHighestNumPath
        }
    elseif ($backupType -eq "2") {
        return $highestNumPath
        }
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

# returns a list wish hash and filenames
function calcHash($path) {
    $hashes = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -Path $path -Force -Attributes !D | ForEach-Object {$hashes.Add($_.FullName); Get-FileHash $_.FullName -Algorithm SHA1} | ForEach-Object {$hashes.Add($_.Hash)}
    return $hashes
    }

# copy files
function copyFile($sourcePath, $destPath, $backupType) {
    if ($backupType -eq "1") {
        Copy-Item -Path $sourcePath -Destination $destPath -Force -Recurse
    }
    elseif ($backupType -eq "2") { 
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        }
    }

# remove files
function removeFile($destPath) {
    Remove-Item -Path $destPath -Force
    }

# get a list of files to copy or remove
function getFileDiff($comparisonList, $referenceList, $cpOrRm) {
    $cpOrRmFiles = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $comparisonList.Count; $i++){
        $comparisonHash = calcHash $comparisonList[$i]
        $referenceHash = calcHash $referenceList[$i]
        for ($ii=1; $ii -lt $comparisonHash.Count; $ii+=2){
            if ($referenceHash.count -gt 0) {
                if (!($referenceHash.Contains($comparisonHash[$ii]))) {
                    $cpOrRmFiles.Add($comparisonHash[$ii-1]) # source file
                    if ($cpOrRm -eq "2"){
                        $parent = Split-Path -Path $comparisonHash[$ii-1] -Leaf
                        $path = Join-Path -Path $referenceList[$i] -ChildPath $parent
                        $cpOrRmFiles.Add($path) # dest file
                        }
                    }
                }
            Else{
                $cpOrRmFiles.Add($comparisonHash[$ii-1]) # source file
                if ($cpOrRm -eq "2"){
                    $parent = Split-Path -Path $comparisonHash[$ii-1] -Leaf
                    $path = Join-Path -Path $referenceList[$i] -ChildPath $parent
                    $cpOrRmFiles.Add($path) # dest file
                    }
                }
            }
        }
    return ,$cpOrRmFiles # , -> unary array operator
}

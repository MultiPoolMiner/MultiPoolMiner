# This script is for developers when updating miner binaries

# binaryhashes.txt contains the SHA256 hash of every executable file in the Bin directory
# which is used to check that the correct version of the miners is installed.
# This script will regenerate the binaryhashes.txt file to match what is currently installed on your system

If(!(Test-Path ".\Bin")) {
    Write-Error "Bin directory does not exist!"
}

# Get list of all the exe files with relative paths, sort to minimize differences when updating git
$binaries = Get-ChildItem -Path Bin -Recurse -Filter "*.exe" | Resolve-Path -Relative | Sort-Object

$hashes = [PSCustomObject]@{}

$binaries | Foreach-Object {
    $hashes | Add-Member $_ (Get-FileHash $_).Hash
}

$hashes | ConvertTo-Json | Out-File -FilePath "binaryhashes.txt" -Encoding ascii
Write-Host "Hashes for binary files updated!"

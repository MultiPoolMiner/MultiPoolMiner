$Path = '.\Bin\Equihash-NiceHash\nheqminer.exe'
$Uri = 'https://github.com/nicehash/nheqminer/releases/download/0.5c/Windows_x64_nheqminer-5c.zip'

if((Test-Path $Path) -eq $false)
{
    $FolderName_Old = ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName
    $FolderName_New = Split-Path (Split-Path $Path) -Leaf
    $FileName = "$FolderName_New$(([IO.FileInfo](Split-Path $Uri -Leaf)).Extension)"

    if(Test-Path $FileName){Remove-Item $FileName}
    if(Test-Path "$(Split-Path (Split-Path $Path))\$FolderName_New"){Remove-Item "$(Split-Path (Split-Path $Path))\$FolderName_New" -Recurse}
    if(Test-Path "$(Split-Path (Split-Path $Path))\$FolderName_Old"){Remove-Item "$(Split-Path (Split-Path $Path))\$FolderName_Old" -Recurse}

    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing
    Start-Process "7z" "x $FileName -o$(Split-Path (Split-Path $Path))\$FolderName_Old -y -spe" -Wait
    Rename-Item "$(Split-Path (Split-Path $Path))\$FolderName_Old" "$FolderName_New"
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Port = 3335

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = Convert-Path $Path
$pinfo.Arguments = "-ci"
$pinfo.UseShellExecute = $false
$pinfo.CreateNoWindow = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $pinfo
$process.Start() | Out-Null
$process.WaitForExit() | Out-Null

$Devices = ($process.StandardOutput.ReadToEnd() | Select-String "#[0-9]" -AllMatches).Matches.Value -replace "#" -join " "

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path
    Arguments = -Join ('-a ', $Port, ' -l $($Pools.Equihash.Host):$($Pools.Equihash.Port) -u $($Pools.Equihash.User) -t 0 -cd ', $Devices)
    HashRates = [PSCustomObject]@{Equihash = '$($Stats.' + $Name + '_Equihash_HashRate.Week)'}
    API = 'Nheqminer'
    Port = $Port
    Wrap = $false
}
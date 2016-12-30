$Path = '.\Bin\Equihash\nheqminer.exe'

if((Test-Path $Path) -eq $false)
{
    $FileName = "nheqminer.zip"
    try
    {
        if(Test-Path $FileName)
        {
            Remove-Item $FileName
        }
        Invoke-WebRequest "https://github.com/nicehash/nheqminer/releases/download/0.4b/nheqminer_v0.4b.zip" -OutFile $FileName -UseBasicParsing
        Expand-Archive $FileName (Split-Path $Path)
    }
    catch
    {
        return
    }
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Port = 3336

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = Convert-Path $Path
$pinfo.Arguments = "-oi"
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
    Type = 'AMD'
    Path = $Path
    Arguments = '-a ' + $Port + ' -l $($Pools.Equihash.Host):$($Pools.Equihash.Port) -u $($Pools.Equihash.User) -t 0 -od ' + $Devices
    HashRates = [PSCustomObject]@{Equihash = '$($Stats.' + $Name + '_Equihash_HashRate.Day)'}
    API = 'Nheqminer_' + $Port
}
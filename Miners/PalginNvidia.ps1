using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Type = "NVIDIA"
if (-not ($Devices.$Type -or $Config.InfoOnly)) {return} # No NVIDIA mining device present in system, InfoOnly is for Get-Binaries

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\HSR-Palgin\hsrminer_hsr.exe"
$HashSHA256 = "C8E13F0B872FBB2A6679EB95456CBCF6C0F0BE84C5173DB948A4FEF9840AC425"
$API = "Ccminer"
$Uri = "https://github.com/palginpav/hsrminer/raw/master/HSR%20algo/Windows/hsrminer_hsr.exe"
$Port = 4001
$Fees = 1
$Commands = [PSCustomObject]@{
    "Hsr" = "" #Hsr
}

$Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_
    
    if ($Pools.$Algorithm_Norm) { # must have a valid pool to mine

        $HashRate = ($Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week)
		
        $HashRate = $HashRate * (1 - $Fees / 100)

        [PSCustomObject]@{
            Name       = $Name
            Type       = $Type
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)")
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
            API        = $Api
            Port       = $Port
            URI        = $Uri
            Fees       = @($Fees)
        }
    }
}

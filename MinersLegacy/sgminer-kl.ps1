using module ..\Include.psm1

$Path = ".\Bin\sgminer-kl\sgminer.exe"
$HashSHA256 = "A24024BEA8789B62D61CB3F41432EA1A62EE5AD97CD3DEAB1E2308F40B127A4D"
$Uri = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.5fix/sgminer-kl-1.0.5_fix-windows_x64.zip"
$ManualUri = "https://github.com/KL0nLutiy"

$Commands = [PSCustomObject]@{
  "aergo"     = " -X 256 -g 2" #Aergo
  "blake"     = "" #Blake
  "bmw"       = "" #Bmw
  "echo"      = "" #Echo
  "hamsi"     = "" #Hamsi
  "keccak"    = "" #Keccak
  "phi"       = " -X 256 -g 2 -w 256" # Phi
  "skein"     = "" #Skein
  "tribus"    = " -X 256 -g 2" #Tribus
  "whirlpool" = "" #Whirlpool
  "xevan"     = " -X 256 -g 2" #Xevan
  "x16s"      = " -X 256 -g 2" #X16S Pigeoncoin
  "x16r"      = " -X 256 -g 2" #X16R Ravencoin
  "x17"       = " -X 256 -g 2"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    if ($Config.IgnoreCosts -or $Config.Miners.$Name.IgnoreCosts) {
        $Miner_Fees = [PSCustomObject]@{"$Algorithm_Norm" = 0 / 100}
    }
    else {
        $Miner_Fees = [PSCustomObject]@{"$Algorithm_Norm" = 1 / 100}
    }

    [PSCustomObject]@{
        Type       = "AMD"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "--api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Xgminer"
        Port       = 4028
        URI        = $Uri
        Fees       = $Miner_Fees
    }
}


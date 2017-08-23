. .\Include.ps1

$Path = ".\Bin\Prospector\prospector.exe"
$Uri = "https://github.com/semtexzv/Prospector/releases/download/0.0.10-ALPHA/prospector-0.0.10-ALPHA-win64.zip"

$Commands = [PSCustomObject]@{
    "xmr" = @() #CryptoNight
    "eth" = @() #Ethash
    "sia" = @() #Sia
    "sigt" = @() #Skunk
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$Port = 42000

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    "[general]
    gpu-coin = ""$_""
    [pools.$_]
    url = ""stratum+tcp://$($Pools.$(Get-Algorithm($_)).Host):$($Pools.$(Get-Algorithm($_)).Port)/""
    username = ""$($Pools.$(Get-Algorithm($_)).User)""
    password = ""$($Pools.$(Get-Algorithm($_)).Pass)""
    [gpus.0-0]
    enabled = true
    [gpus.1-0]
    enabled = true
    [gpus.2-0]
    enabled = true
    [gpus.3-0]
    enabled = true
    [gpus.4-0]
    enabled = true
    [gpus.5-0]
    enabled = true
    [cpu]
    enabled = false" | Set-Content "$(Split-Path $Path)\$($Pools.$(Get-Algorithm($_)).Name)_$(Get-Algorithm($_)).toml" -Force -ErrorAction SilentlyContinue
    
    [PSCustomObject]@{
        Type = "AMD", "NVIDIA"
        Path = $Path
        Arguments = "-c $($Pools.$(Get-Algorithm($_)).Name)_$(Get-Algorithm($_)).toml"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = "Prospector"
        Port = $Port
        Wrap = $false
        URI = $Uri
    }

    if ($_ -eq "eth") {
        [PSCustomObject]@{
            Type = "AMD", "NVIDIA"
            Path = $Path
            Arguments = "-c $($Pools.$(Get-Algorithm($_)).Name)_$(Get-Algorithm($_))2gb.toml"
            HashRates = [PSCustomObject]@{"$(Get-Algorithm($_))2gb" = $Stats."$($Name)_$(Get-Algorithm($_))2gb_HashRate".Week}
            API = "Prospector"
            Port = $Port
            Wrap = $false
            URI = $Uri
        }
    }
}
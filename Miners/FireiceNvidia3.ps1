using module ..\Include.psm1

$ThreadIndex = 3

$Path = ".\Bin\CryptoNight-FireIceNVIDIA\xmr-stak-nvidia.exe"
$Uri = "https://github.com/fireice-uk/xmr-stak-nvidia/releases/download/v1.1.1-1.4.0/xmr-stak-nvidia.zip"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3335 + ($ThreadIndex * 10000)

if ($Pools.CryptoNight.Name -eq "NiceHash") {return} #temp fix

([PSCustomObject]@{
        gpu_threads_conf = @([PSCustomObject]@{index = $ThreadIndex; threads = 32; blocks = 84; bfactor = 6; bsleep = 25; affine_to_cpu = $true})
        use_tls          = $Pools.CryptoNight.SSL
        tls_secure_algo  = $true
        tls_fingerprint  = ""
        pool_address     = "$($Pools.CryptoNight.Host):$($Pools.CryptoNight.Port)"
        wallet_address   = "$($Pools.CryptoNight.User)"
        pool_password    = "$($Pools.CryptoNight.Pass)"
        call_timeout     = 10
        retry_time       = 10
        giveup_limit     = 0
        verbose_level    = 3
        h_print_time     = 60
        output_file      = ""
        httpd_port       = $Port
        prefer_ipv4      = $true
    } | ConvertTo-Json -Depth 10) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path)\$($Pools.CryptoNight.Name)_CryptoNight_$($ThreadIndex).txt" -Force -ErrorAction SilentlyContinue

[PSCustomObject]@{
    Type      = "NVIDIA"
    Path      = $Path
    Arguments = "-c $($Pools.CryptoNight.Name)_CryptoNight_$($ThreadIndex).txt"
    HashRates = [PSCustomObject]@{CryptoNight = $Stats."$($Name)_CryptoNight_HashRate".Week}
    API       = "XMRig"
    Port      = $Port
    Wrap      = $false
    URI       = $Uri
    Index     = $ThreadIndex
}
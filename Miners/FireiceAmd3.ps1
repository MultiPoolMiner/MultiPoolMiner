using module ..\Include.psm1

$ThreadIndex = 3

$Path = ".\Bin\CryptoNight-FireIceAMD\xmr-stak-amd.exe"
$Uri = "https://github.com/fireice-uk/xmr-stak-amd/releases/download/v1.1.0-1.4.0/xmr-stak-amd-win64.zip"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3336 + ($ThreadIndex * 10000)

if ($Pools.CryptoNight.Name -eq "NiceHash") {return} #temp fix

([PSCustomObject]@{
        gpu_thread_num   = 1
        gpu_threads_conf = @([PSCustomObject]@{index = $ThreadIndex; intensity = 1000; worksize = 8; affine_to_cpu = $true})
        platform_index   = [array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.')
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
        daemon_mode      = $false
    } | ConvertTo-Json -Depth 10) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path)\$($Pools.CryptoNight.Name)_CryptoNight_$($ThreadIndex).txt" -Force -ErrorAction SilentlyContinue

[PSCustomObject]@{
    Type      = "AMD"
    Path      = $Path
    Arguments = "-c $($Pools.CryptoNight.Name)_CryptoNight_$($ThreadIndex).txt"
    HashRates = [PSCustomObject]@{CryptoNight = $Stats."$($Name)_CryptoNight_HashRate".Week}
    API       = "XMRig"
    Port      = $Port
    Wrap      = $false
    URI       = $Uri
    Index     = $ThreadIndex
}

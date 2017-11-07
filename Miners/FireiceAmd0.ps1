using module ..\Include.psm1

$ThreadIndex = 0
$Path_Threads = ".\Bin\CryptoNight-AMD$ThreadIndex\xmr-stak-amd.exe"

$Path = ".\Bin\CryptoNight-AMD\xmr-stak-amd.exe"
$Uri = "https://github.com/fireice-uk/xmr-stak-amd/releases/download/v1.1.0-1.4.0/xmr-stak-amd-win64.zip"

if ((Test-Path $Path) -eq $false) {Expand-WebRequest $Uri (Split-Path $Path) -ErrorAction SilentlyContinue}
if ((Test-Path $Path_Threads) -eq $false) {Copy-Item (Split-Path $Path) (Split-Path $Path_Threads) -Recurse -Force -ErrorAction SilentlyContinue}

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
    } | ConvertTo-Json -Depth 10) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path_Threads)\config.txt" -Force -ErrorAction SilentlyContinue

[PSCustomObject]@{
    Type      = "AMD"
    Path      = $Path_Threads
    Arguments = ''
    HashRates = [PSCustomObject]@{CryptoNight = $Stats."$($Name)_CryptoNight_HashRate".Week}
    API       = "FireIce"
    Port      = $Port
    Wrap      = $false
    URI       = $Uri
    Index     = $ThreadIndex
}

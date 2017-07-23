. .\Include.ps1

$ThreadIndex = 3
$Path_Threads = ".\Bin\Cryptonight-NVIDIA$ThreadIndex\xmr-stak-nvidia.exe"

$Path = ".\Bin\Cryptonight-NVIDIA\xmr-stak-nvidia.exe"
$Uri = "https://github.com/fireice-uk/xmr-stak-nvidia/releases/download/v1.1.1-1.4.0/xmr-stak-nvidia.zip"

if ((Test-Path $Path) -eq $false) {Expand-WebRequest $Uri (Split-Path $Path) -ErrorAction SilentlyContinue}
if ((Test-Path $Path_Threads) -eq $false) {Copy-Item (Split-Path $Path) (Split-Path $Path_Threads) -Recurse -Force -ErrorAction SilentlyContinue}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$Port = 3335 + ($ThreadIndex * 10000)

([PSCustomObject]@{
        gpu_threads_conf = @([PSCustomObject]@{index = $ThreadIndex; threads = 17; blocks = 60; bfactor = 0; bsleep = 0; affine_to_cpu = $true})
        use_tls          = $false
        tls_secure_algo  = $true
        tls_fingerprint  = ""
        pool_address     = "$($Pools.Cryptonight.Host):$($Pools.Cryptonight.Port)"
        wallet_address   = "$($Pools.Cryptonight.User)"
        pool_password    = "$($Pools.Cryptonight.Pass)"
        call_timeout     = 10
        retry_time       = 10
        giveup_limit     = 0
        verbose_level    = 3
        h_print_time     = 60
        output_file      = ""
        httpd_port       = $Port
        prefer_ipv4      = $true
    } | ConvertTo-Json -Depth 10) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path_Threads)\config.txt" -Force -ErrorAction SilentlyContinue

[PSCustomObject]@{
    Type      = "NVIDIA"
    Path      = $Path_Threads
    Arguments = ''
    HashRates = [PSCustomObject]@{Cryptonight = $Stats."$($Name)_Cryptonight_HashRate".Week}
    API       = "FireIce"
    Port      = $Port
    Wrap      = $false
    URI       = $Uri
    Index     = $ThreadIndex
}
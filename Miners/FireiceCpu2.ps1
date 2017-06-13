. .\Include.ps1

$Threads = 2
$Path_Threads = ".\Bin\Cryptonight-CPU$Threads\xmr-stak-cpu.exe"

$Path = ".\Bin\Cryptonight-CPU\xmr-stak-cpu.exe"
$Uri = "https://github.com/fireice-uk/xmr-stak-cpu/releases/download/v1.2.0-1.4.1/xmr-stak-cpu-win64.zip"

if((Test-Path $Path) -eq $false){Expand-WebRequest $Uri (Split-Path $Path) -ErrorAction SilentlyContinue}
if((Test-Path $Path_Threads) -eq $false){Copy-Item (Split-Path $Path) (Split-Path $Path_Threads) -Recurse -Force -ErrorAction SilentlyContinue}

if((Test-Path $Path) -eq $false){Move-Item "$(Split-Path $Path)\xmr-stak-cpu\*" (Split-Path $Path) -Force -ErrorAction SilentlyContinue} #temp fix
if((Test-Path $Path_Threads) -eq $false){Move-Item "$(Split-Path $Path_Threads)\xmr-stak-cpu\*" (Split-Path $Path_Threads) -Force -ErrorAction SilentlyContinue} #temp fix

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$Port = 3334+($ThreadIndex*10000)

([PSCustomObject]@{
    cpu_threads_conf = @([PSCustomObject]@{low_power_mode = $false; no_prefetch = $true; affine_to_cpu = $false})*$Threads
    use_slow_memory = "warn"
    nicehash_nonce = $true
    use_tls = $false
    tls_secure_algo = $true
    tls_fingerprint = ""
    pool_address = "$($Pools.Cryptonight.Host):$($Pools.Cryptonight.Port)"
    wallet_address = "$($Pools.Cryptonight.User)"
    pool_password = "$($Pools.Cryptonight.Pass)"
    call_timeout = 10
    retry_time = 10
    giveup_limit = 0
    verbose_level = 3
    h_print_time = 60
    output_file = ""
    httpd_port = $Port
    prefer_ipv4 = $true
} | ConvertTo-Json -Depth 10) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path_Threads)\config.txt" -Force -ErrorAction SilentlyContinue

[PSCustomObject]@{
    Type = "CPU"
    Path = $Path_Threads
    Arguments = ''
    HashRates = [PSCustomObject]@{Cryptonight = $Stats."$($Name)_Cryptonight_HashRate".Week}
    API = "FireIce"
    Port = $Port
    Wrap = $false
    URI = $Uri
}
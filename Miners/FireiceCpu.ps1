using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-FireIce\xmr-stak.exe"
$Uri = "https://github.com/fireice-uk/xmr-stak/releases/download/v2.0.0/xmr-stak-win64.zip"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3334

New-Item -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" -Force | New-ItemProperty -Name ([System.IO.Path]::GetFullPath($Path)) -Value "RunAsInvoker" -Force | Out-Null #temp fix

([PSCustomObject]@{
        pool_list       = @([PSCustomObject]@{
                pool_address    = "$($Pools.CryptoNight.Host):$($Pools.CryptoNight.Port)"
                wallet_address  = "$($Pools.CryptoNight.User)"
                pool_password   = "$($Pools.CryptoNight.Pass)"
                use_nicehash    = $true
                use_tls         = $Pools.CryptoNight.SSL
                tls_fingerprint = ""
                pool_weight     = 1
            }
        )
        currency        = "monero"
        call_timeout    = 10
        retry_time      = 10
        giveup_limit    = 0
        verbose_level   = 3
        print_motd      = $true
        h_print_time    = 60
        aes_override    = $null
        use_slow_memory = "warn"
        tls_secure_algo = $true
        daemon_mode     = $false
        flush_stdout    = $false
        output_file     = ""
        httpd_port      = $Port
        http_login      = ""
        http_pass       = ""
        prefer_ipv4     = $true
    } | ConvertTo-Json -Depth 10
) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path)\$($Pools.CryptoNight.Name)_CryptoNight_$($Pools.CryptoNight.User)_Cpu.txt" -Force -ErrorAction SilentlyContinue

[PSCustomObject]@{
    Type      = "CPU"
    Path      = $Path
    Arguments = "-c $($Pools.CryptoNight.Name)_CryptoNight_$($Pools.CryptoNight.User)_Cpu.txt --noAMD --noNVIDIA"
    HashRates = [PSCustomObject]@{CryptoNight = $Stats."$($Name)_CryptoNight_HashRate".Week}
    API       = "XMRig"
    Port      = $Port
    Wrap      = $false
    URI       = $Uri
}
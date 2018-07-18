using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-FireIce\xmr-stak.exe"
$HashSHA256 = "1BFEAA00CCE185C889F82A2C87DCACABF2EE966B379384470E778E1DA72FB7E1"
$Uri = "https://github.com/fireice-uk/xmr-stak/releases/download/2.4.5/xmr-stak-win64.zip"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3336

$Commands = [PSCustomObject]@{
    # "cryptonight"           = "" # CryptoNight is ASIC territory
    "cryptonight_haven"       = "" # CryptoNightHaven
    "cryptonight_heavy"       = "" # CryptoNightHeavy
    "cryptonight_lite"        = "" # CryptoNightLite
    "cryptonight_lite_v7"     = "" # CryptoNightLiteV7
    "cryptonight_lite_v7_xor" = "" # CryptoNightLiteV7Xor
    "cryptonight_masari"      = "" # CryptoNightMasari
    "cryptonight_v7_stellite" = "" # CryptoNightV7Stellite
    "cryptonight_v7"          = "" # CryptoNightV7
}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.$(Get-Algorithm $_)} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    ([PSCustomObject]@{
            pool_list       = @([PSCustomObject]@{
                    pool_address    = "$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                    wallet_address  = "$($Pools.$Algorithm_Norm.User)"
                    pool_password   = "$($Pools.$Algorithm_Norm.Pass)"
                    use_nicehash    = $true
                    use_tls         = $Pools.$Algorithm_Norm.SSL
                    tls_fingerprint = ""
                    pool_weight     = 1
                    rig_id = ""
                }
            )
            currency        = if ($Pools.$Algorithm_Norm.Info) {"$($Pools.$Algorithm_Norm.Info -replace '^monero$', 'monero7' -replace '^aeon$', 'aeon7')"} else {"$_"}
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
    ) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path)\$($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_Amd.txt" -Force -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        Type      = "AMD"
        Path      = $Path
        HashSHA256 = $HashSHA256
        Arguments = "-C $($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_Amd.txt --noUAC --noCPU --noNVIDIA -i $($Port)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API       = "XMRig"
        Port      = $Port
        URI       = $Uri
    }
}

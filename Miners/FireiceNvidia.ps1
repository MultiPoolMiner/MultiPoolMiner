using module ..\Include.psm1

$ThreadIndex = 0

$Path = ".\Bin\CryptoNight-FireIce\xmr-stak.exe"
$Uri = "https://github.com/fireice-uk/xmr-stak/releases/download/v2.2.0/xmr-stak-win64.zip"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Type = "NVIDIA"

#New-Item -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" -Force | New-ItemProperty -Name ([System.IO.Path]::GetFullPath($Path)) -Value "RunAsInvoker" -Force #temp fix

if ($Pools.Cryptonight.Name) {

    $Port = 3335

    $Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
    $Devices | ForEach-Object {

        if ($Devices.count -gt 1 ){
            $Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($_.Device_Norm)"
            $HWConfigFile = " --$($_.Type.ToLower()) $($_.Device_Norm).txt"
        }

        {while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null

        ([PSCustomObject]@{
            pool_list = @([PSCustomObject]@{
                pool_address    = "$($Pools.CryptoNight.Host):$($Pools.CryptoNight.Port)"
                wallet_address  = "$($Pools.CryptoNight.User)"
                pool_password   = "$($Pools.CryptoNight.Pass)"
                use_nicehash    = $true
                use_tls         = $Pools.CryptoNight.SSL
                tls_fingerprint = ""
                pool_weight     = 1
            })
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
        ) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path)\$($Name)_$($Pools.CryptoNight.Name)_CryptoNight.txt" -Force -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            Name        = $Name
            Type		= $Type
            Device		= $_.Device
            Devices		= $_.Devices
            Path		= $Path
            Arguments = "-c $($Name)_$($Pools.CryptoNight.Name)_CryptoNight.txt --noAMD --noCPU --noUAC$HWConfigFile"
            HashRates	= [PSCustomObject]@{"CryptoNight" = $Stats."$($Name)_CryptoNight_HashRate".Week}
            API			= "XMRig"
            Port		= $Port
            Wrap		= $false
            URI			= $Uri
            PowerDraw	= $Stats."$($Name)_CryptoNight_$($Pools.CryptoNight.Name)_PowerDraw".Week
            ComputeUsage= $Stats."$($Name)_CryptoNight_$($Pools.CryptoNight.Name)_ComputeUsage".Week
            Pool		= "$($Pools.CryptoNight.Name)"
        }
        if ($Port) {$Port ++}
    }
}
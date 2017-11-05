using module ..\Include.psm1

class Xgminer : Miner {
    [PSCustomObject]GetHashRate ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $Request = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress

        do {
            $HashRate = [PSCustomObject]@{}
            $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = $null}}
            $HashRates += $HashRate

            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout

            $Data = $Response.Substring($Response.IndexOf("{"), $Response.LastIndexOf("}") - $Response.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json

            $HashRate_Name = $HashRate | Get-Member -MemberType NoteProperty | Select-Object -First 1 -ExpandProperty Name
            $HashRate_Value = if ($Data.SUMMARY.HS_5s -ne $null) {[Double]$Data.SUMMARY.HS_5s * [Math]::Pow(1000, 0)}
            elseif ($Data.SUMMARY.KHS_5s -ne $null) {[Double]$Data.SUMMARY.KHS_5s * [Math]::Pow(1000, 1)}
            elseif ($Data.SUMMARY.MHS_5s -ne $null) {[Double]$Data.SUMMARY.MHS_5s * [Math]::Pow(1000, 2)}
            elseif ($Data.SUMMARY.GHS_5s -ne $null) {[Double]$Data.SUMMARY.GHS_5s * [Math]::Pow(1000, 3)}
            elseif ($Data.SUMMARY.THS_5s -ne $null) {[Double]$Data.SUMMARY.THS_5s * [Math]::Pow(1000, 4)}
            elseif ($Data.SUMMARY.PHS_5s -ne $null) {[Double]$Data.SUMMARY.PHS_5s * [Math]::Pow(1000, 5)}

            if ($HashRate_Name -and ($HashRate | Get-Member -MemberType NoteProperty | Measure-Object).Count -eq 1) {
                if ($HashRate_Value -ne $null) {$HashRate.(Get-Algorithm $HashRate_Name) = $HashRate_Value}
            }

            $HashRate | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
                if ($HashRate.$_ -eq $null) {$HashRates = @(); break}
            }

            if (-not $Safe) {break}

            $HashRate = [PSCustomObject]@{}
            $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = $null}}
            $HashRates += $HashRate

            $HashRate_Value = if ($Data.SUMMARY.HS_av -ne $null) {[Double]$Data.SUMMARY.HS_av * [Math]::Pow(1000, 0)}
            elseif ($Data.SUMMARY.KHS_av -ne $null) {[Double]$Data.SUMMARY.KHS_av * [Math]::Pow(1000, 1)}
            elseif ($Data.SUMMARY.MHS_av -ne $null) {[Double]$Data.SUMMARY.MHS_av * [Math]::Pow(1000, 2)}
            elseif ($Data.SUMMARY.GHS_av -ne $null) {[Double]$Data.SUMMARY.GHS_av * [Math]::Pow(1000, 3)}
            elseif ($Data.SUMMARY.THS_av -ne $null) {[Double]$Data.SUMMARY.THS_av * [Math]::Pow(1000, 4)}
            elseif ($Data.SUMMARY.PHS_av -ne $null) {[Double]$Data.SUMMARY.PHS_av * [Math]::Pow(1000, 5)}

            if ($HashRate_Name -and ($HashRate | Get-Member -MemberType NoteProperty | Measure-Object).Count -eq 1) {
                if ($HashRate_Value -ne $null) {$HashRate.(Get-Algorithm $HashRate_Name) = $HashRate_Value}
            }

            $HashRate | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
                if ($HashRate.$_ -eq $null) {$HashRates = @(); break}
            }

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRates_Info = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRates_Info | Add-Member @{$_ = $HashRates | Measure-Object $_ -Maximum -Minimum -Average}}
        $HashRate = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = if ($HashRates_Info.$_.Maximum - $HashRates_Info.$_.Minimum -le $HashRates_Info.$_.Average * $Delta) {$HashRates_Info.$_.Maximum}}}

        return $HashRate
    }
}
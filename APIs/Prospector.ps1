using module ..\Include.psm1

class Prospector : Miner {
    [PSCustomObject]GetHashRate ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        do {
            $HashRate = [PSCustomObject]@{}
            $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = $null}}
            $HashRates += $HashRate

            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v0/hashrates" -UseBasicParsing -TimeoutSec $Timeout

            $Data = $Response | ConvertFrom-Json

            $HashRate_Name = $Data.coin
            $HashRate_Value = $Data.rate

            if ($HashRate_Name -and ($HashRate | Get-Member -MemberType NoteProperty | Where-Object Name -EQ (Get-Algorithm $HashRate_Name) | Measure-Object).Count -eq 1) {
                if ($HashRate_Value -ne $null) {$HashRate.(Get-Algorithm $HashRate_Name) = [Double]($HashRate_Value | Measure-Object -Sum).Sum}
            }

            $HashRate | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
                if ($HashRate.$_ -eq $null) {$HashRates = @(); break}
            }

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRates_Info = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRates_Info | Add-Member @{$_ = $HashRates | Measure-Object $_ -Maximum -Minimum -Average}}
        $HashRate = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = if ($HashRates_Info.$_.Maximum - $HashRates_Info.$_.Minimum -le $HashRates_Info.$_.Average * $Delta) {$HashRates_Info.$_.Maximum}}}

        return $HashRate
    }
}
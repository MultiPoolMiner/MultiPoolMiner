using module ..\Include.psm1

class Ccminer : Miner {
    [PSCustomObject]GetHashRate ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $Request = "summary"

        do {
            $HashRate = [PSCustomObject]@{}
            $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = $null}}
            $HashRates += $HashRate

            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout

            $Data = $Response -split ";" | ConvertFrom-StringData

            $HashRate_Name = $Data.algo
            $HashRate_Value = if ([Double]$Data.ACC -ne 0 -or [Double]$Data.KHS -ne 0) {$Data.KHS}

            if ($HashRate_Name -and ($HashRate | Get-Member -MemberType NoteProperty | Where-Object Name -EQ (Get-Algorithm $HashRate_Name) | Measure-Object).Count -eq 1) {
                if ($HashRate_Value -ne $null) {$HashRate.(Get-Algorithm $HashRate_Name) = [Double]$HashRate_Value * 1000}
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
using module ..\Include.psm1

class Wrapper : Miner {
    [PSCustomObject]GetHashRate ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        do {
            $HashRate = [PSCustomObject]@{}
            $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = $null}}
            $HashRates += $HashRate

            $Response = Get-Content ".\Wrapper_$($this.Port).txt" -ErrorAction Ignore

            $Data = $Response | ConvertFrom-Json

            if ($Data -eq $null) {
                Start-Sleep $Interval
                $Response = Get-Content ".\Wrapper_$($this.Port).txt" | ConvertFrom-Json
                $Data = $Response | ConvertFrom-Json
            }

            $HashRate_Name = $HashRate | Get-Member -MemberType NoteProperty | Select-Object -First 1 -ExpandProperty Name
            $HashRate_Value = $Data

            if ($HashRate_Name -and ($HashRate | Get-Member -MemberType NoteProperty | Measure-Object).Count -eq 1) {
                if ($HashRate_Value -ne $null) {$HashRate.(Get-Algorithm $HashRate_Name) = [Double]$HashRate_Value}
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
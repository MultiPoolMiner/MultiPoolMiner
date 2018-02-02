using module ..\Include.psm1

class Nicehash : Miner {
    [PSCustomObject]GetData ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
        
        $PowerDraws = @()
        $ComputeUsages = @()
        
        $Response = ""
        $Data = ""
        
        do {
            # Read Data from hardware
            $ComputeData = [PSCustomObject]@{}
            $ComputeData = (Get-ComputeData -MinerType $this.type -Index $this.index)
            $PowerDraws += $ComputeData.PowerDraw
            $ComputeUsages += $ComputeData.ComputeUsage
            
            $HashRates += $HashRate = [PSCustomObject]@{}

            try {
                $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            }
            catch {}

            $Data.algorithms.name | Select-Object -Unique | ForEach-Object {
                $HashRate_Name = [String]($Algorithm -like (Get-Algorithm $_))
                if (-not $HashRate_Name) {$HashRate_Name = [String]($Algorithm -like "$(Get-Algorithm $_)*")} #temp fix
                $HashRate_Value = [Double](($Data.algorithms | Where-Object name -EQ $_).workers.speed | Measure-Object -Sum).Sum

                $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}                
            }

            $Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRate = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
        $Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$Algorithm | ForEach-Object {$HashRate.$_ = [Int64]0}}

        $PowerDraws_Info = [PSCustomObject]@{}
        $PowerDraws_Info = ($PowerDraws | Measure-Object -Maximum -Minimum -Average)
        $PowerDraw = if ($PowerDraws_Info.Maximum - $PowerDraws_Info.Minimum -le $PowerDraws_Info.Average * $Delta) {$PowerDraws_Info.Maximum} else {$PowerDraws_Info.Average}

        $ComputeUsages_Info = [PSCustomObject]@{}
        $ComputeUsages_Info = ($ComputeUsages | Measure-Object -Maximum -Minimum -Average)
        $ComputeUsage = if ($ComputeUsages_Info.Maximum - $ComputeUsages_Info.Minimum -le $ComputeUsages_Info.Average * $Delta) {$ComputeUsages_Info.Maximum} else {$ComputeUsages_Info.Average}
        
        return [PSCustomObject]@{
            HashRate     = $HashRate
            PowerDraw    = $PowerDraw
            ComputeUsage = $ComputeUsage
            Response     = $Response
        }
    }
}
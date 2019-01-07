using module ..\Include.psm1

class Mkxminer : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = "statistics"
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest -Server $Server -Port $this.Port -Request "stats" $Timeout -ReadToEnd $true -ErrorAction Stop
            $Data = $Response -replace "`0" | ConvertFrom-Json -ErrorAction Stop # Miner adds hidden nul charactor to terminate the response
        }
        catch {
            if ((Get-Date) -gt ($this.Process.PSBeginTime.AddSeconds(30))) {$this.SetStatus("Failed")}
            return @($Request, $Response)
        }

        $HashRate_Name = [String]$this.Algorithm[0]

        $Accepted_Shares = [Int64]0
        $Bad_Shares = [Int64]0
        if ($this.AllowedBadShareRatio -and ((-not $Accepted_Shares -and $Bad_Shares -ge 3) -or ($Accepted_Shares + $Bad_Shares -ge [Int](1 / $this.AllowedBadShareRatio)) -and $Accepted_Shares * (1 - $this.AllowedBadShareRatio) -lt $Bad_Shares * $this.AllowedBadShareRatio)) {
            $this.SetStatus("Failed")
            $this.StatusMessage = " was stopped because of too many bad shares for algorithm $($HashRate_Name) (total: $($Accepted_Shares + $Bad_Shares) / bad: $($Bad_Shares) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
            return @($Request, $Response)
        }

        $HashRate_Value = [Double]$Data.gpus.hashrate * 1000000
        if ($HashRate_Name -and $HashRate_Value -GT 0) {$HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}}

        if ($HashRate | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) {
            $this.Data += [PSCustomObject]@{
                Date       = (Get-Date).ToUniversalTime()
                Raw        = $Response
                HashRate   = $HashRate
                PowerUsage = (Get-PowerUsage $this.DeviceName)
                Device     = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}
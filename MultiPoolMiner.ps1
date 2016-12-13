####################################################################
# HashRate is measured in the smallest unit (Hash per Second).     #
# You must enter the HashRate for each miner that you wish to use. #
####################################################################

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)
 
#$Wallet = "[enter wallet here]"
$Username = "[enter username here]"
$Worker = "MultiPoolMiner"

$Interval = 30 #seconds
$ZecMiner64_Path = "C:\ZecMiner64\ZecMiner64.exe" 
$EthDcrMiner64_Path = "C:\EthDcrMiner64\EthDcrMiner64.exe"
$sgminer_Path = "C:\sgminer\sgminer.exe"

function Set-Stat
{
    param( $Name, $Value, $Date )
    
    if($Value -eq 0)
    {
        $Value = 0.00000000000001
    }

    if(Test-Path ($Name + ".txt"))
    {
        $Stat = Get-Content ($Name + ".txt") -ErrorAction Stop | ConvertFrom-Json
    }
    else
    {
        $Stat = [PSCustomObject]@{ Live = $Value; Minute = $Value; Minute_5 = $Value; Minute_10 = $Value; Hour = $Value; Day = $Value; Week = $Value; Updated = [DateTime]0 }
    }

    if($Date -isnot [DateTime])
    {
        $Date = Get-Date
    }
    
    $Date = $Date.ToUniversalTime()

    if($Value -is [ValueType])
    {
        $Stat = [PSCustomObject]@{
            Live = $Value
            Minute = ((1-[math]::Min(($Date-$Stat.Updated).TotalMinutes,1))*$Stat.Minute)+([math]::Min(($Date-$Stat.Updated).TotalMinutes,1)*$Value)
            Minute_Fluctuation = ((1-[math]::Min(($Date-$Stat.Updated).TotalMinutes,1))*$Stat.Minute_Fluctuation)+([math]::Min(($Date-$Stat.Updated).TotalMinutes,1)*([math]::Abs($Value-$Stat.Minute)/$Stat.Minute))
            Minute_5 = ((1-[math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1))*$Stat.Minute_5)+([math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1)*$Value)
            Minute_5_Fluctuation = ((1-[math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1))*$Stat.Minute_5_Fluctuation)+([math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1)*([math]::Abs($Value-$Stat.Minute_5)/$Stat.Minute_5))
            Minute_10 = ((1-[math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1))*$Stat.Minute_10)+([math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1)*$Value)
            Minute_10_Fluctuation = ((1-[math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1))*$Stat.Minute_10_Fluctuation)+([math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1)*([math]::Abs($Value-$Stat.Minute_10)/$Stat.Minute_10))
            Hour = ((1-[math]::Min(($Date-$Stat.Updated).TotalHours,1))*$Stat.Hour)+([math]::Min(($Date-$Stat.Updated).TotalHours,1)*$Value)
            Hour_Fluctuation = ((1-[math]::Min(($Date-$Stat.Updated).TotalHours,1))*$Stat.Hour_Fluctuation)+([math]::Min(($Date-$Stat.Updated).TotalHours,1)*([math]::Abs($Value-$Stat.Hour)/$Stat.Hour))
            Day = ((1-[math]::Min(($Date-$Stat.Updated).TotalDays,1))*$Stat.Day)+([math]::Min(($Date-$Stat.Updated).TotalDays,1)*$Value)
            Day_Fluctuation = ((1-[math]::Min(($Date-$Stat.Updated).TotalDays,1))*$Stat.Day_Fluctuation)+([math]::Min(($Date-$Stat.Updated).TotalDays,1)*([math]::Abs($Value-$Stat.Day)/$Stat.Day))
            Week = ((1-[math]::Min((($Date-$Stat.Updated).TotalDays/7),1))*$Stat.Week)+([math]::Min((($Date-$Stat.Updated).TotalDays/7),1)*$Value)
            Week_Fluctuation = ((1-[math]::Min((($Date-$Stat.Updated).TotalDays/7),1))*$Stat.Week_Fluctuation)+([math]::Min((($Date-$Stat.Updated).TotalDays/7),1)*([math]::Abs($Value-$Stat.Week)/$Stat.Week))
            Updated = $Date
        }
        
        Set-Content ($Name + ".txt") ($Stat | ConvertTo-Json)
    }

    $Stat
}

$CurrentMiner = $null

while($true)
{
    $Miners = @()
    $Pools = @()

    #begin loading miners
    $Miners += [PSCustomObject]@{
        Path = $EthDcrMiner64_Path
        Arguments = "-epool [Ethash.Host]:[Ethash.Port] -ewal [Ethash.User] -epsw x -esm 3 -allpools 1 -mport 0 -dpool [Sia.Host]:[Sia.Port] -dwal [Sia.User] -dpsw x"
        HashRates = @{Ethash = 0; Sia = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $ZecMiner64_Path 
        Arguments = "-zpool [Equihash.Host]:[Equihash.Port] -zwal [Equihash.User] -zpsw x -mport 0 -i 8"
        HashRates = @{Equihash = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k ??? -o [Sia.Host]:[Sia.Port] -u [Sia.User] -p x"
        HashRates = @{Sia = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k ??? -o [Yescrypt.Host]:[Yescrypt.Port] -u [Yescrypt.User] -p x"
        HashRates = @{Yescrypt = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $EthDcrMiner64_Path
        Arguments = "-epool [Ethash.Host]:[Ethash.Port] -ewal [Ethash.User] -epsw x -esm 3 -allpools 1 -mport 0"
        HashRates = @{Ethash = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k vanilla -o [Blake_Vanilla.Host]:[Blake_Vanilla.Port] -u [Blake_Vanilla.User] -p x"
        HashRates = @{Blake_Vanilla = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k lyra2rev2 -o [Lyra2RE2.Host]:[Lyra2RE2.Port] -u [Lyra2RE2.User] -p x"
        HashRates = @{Lyra2RE2 = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k skeincoin -o [Skein.Host]:[Skein.Port] -u [Skein.User] -p x"
        HashRates = @{Skein = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k qubitcoin -o [Qubit.Host]:[Qubit.Port] -u [Qubit.User] -p x"
        HashRates = @{Qubit = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k neoscrypt -o [NeoScrypt.Host]:[NeoScrypt.Port] -u [NeoScrypt.User] -p x"
        HashRates = @{NeoScrypt = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k darkcoin-mod -o [X11.Host]:[X11.Port] -u [X11.User] -p x"
        HashRates = @{X11 = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k myriadcoin-groestl -o [Myriad_Groestl.Host]:[Myriad_Groestl.Port] -u [Myriad_Groestl.User] -p x"
        HashRates = @{Myriad_Groestl = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k groestlcoin -o [Groestl.Host]:[Groestl.Port] -u [Groestl.User] -p x"
        HashRates = @{Groestl = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k maxcoin -o [Keccak.Host]:[Keccak.Port] -u [Keccak.User] -p x"
        HashRates = @{Keccak = 0} #SET YOUR HASH RATE!
    }

    $Miners += [PSCustomObject]@{
        Path = $sgminer_Path
        Arguments = "-k zuikkis -o [Scrypt.Host]:[Scrypt.Port] -u [Scrypt.User] -p x"
        HashRates = @{Scrypt = 0} #SET YOUR HASH RATE!
    }
    #end loading pools
    
    #begin loading pools
    $Updated = Get-Date
    $MiningPoolHub_Request = Invoke-WebRequest -Uri "https://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics" | ConvertFrom-Json
    
    if(-not $MiningPoolHub_Request.success)
    {
        Sleep 1
        continue
    }

    $MiningPoolHub_Request.return | ForEach {
        $Stat = Set-Stat -Name ("MiningPoolHub_"+$_.algo.Replace("-","_")+"_Profit") -Value ([decimal]$_.profit/1000000000) -Date $Updated
        $Pool = [PSCustomObject]@{
            Name = "MiningPoolHub"
            Algorithm = $_.algo.Replace("-","_")
            Price = (($Stat.Live*(1-[Math]::Min($Stat.Hour_Fluctuation,1)))+($Stat.Hour*(0+[Math]::Min($Stat.Hour_Fluctuation,1))))
            Host = $_.host
            Port = $_.algo_switch_port
            User = $Username + "." + "MultiAlgoMiner"
            Pass = "x"
        }
        $Pools += $Pool
    }
    #end loading pools

    $Miners | ForEach {
        $Miner = $_
        $Miner_Pools = @{}
        $Miner_Profits = @{}

        $Miner.HashRates.Keys | ForEach {
           $Miner_Pools.Add($_, ($Pools | Where Algorithm -EQ $_ | Sort -Descending Price)[0])
        }
        $Miner.HashRates.Keys | ForEach {
           $Miner_Profits.Add($_, $Miner.HashRates[$_]*($Pools | Where Algorithm -EQ $_ | Sort -Descending Price)[0].Price)
        }

        Add-Member -InputObject $_ -MemberType NoteProperty -Name Pools -Value $Miner_Pools
        Add-Member -InputObject $_ -MemberType NoteProperty -Name Profits -Value $Miner_Profits
        Add-Member -InputObject $_ -MemberType NoteProperty -Name Profit -Value ($Miner_Profits.Values | Measure -Sum).Sum
    }
    
    Clear-Host
    $Miners | Sort -Descending Profit | Format-Table (
        @{Label = "Algorithm"; Expression={$_.HashRates.Keys}}, 
        @{Label = "BTC/Day"; Expression={$_.Profits.Values | ForEach {$_.ToString("0.00000")}}; Align='right'}, 
        @{Label = "Pool"; Expression={$_.Pools.Values.Name}}, 
        @{Label = "BTC/GH/Day"; Expression={$_.Pools.Values.Price | ForEach {($_*1000000000).ToString("0.00000")}}; Align='right'}
    ) | Out-Host

    $NewMiner = ($Miners | Sort -Descending Profit)[0]

    if($CurrentMiner -eq $null -or $CurrentMiner.Path -ne $NewMiner.Path -or $CurrentMiner.Arguments -ne $NewMiner.Arguments)
    {
        $Miner_Path = $NewMiner.Path
        $Miner_Arguments = $NewMiner.Arguments

        $NewMiner.Pools.Keys | ForEach {
            $Miner_Arguments = $Miner_Arguments.`
            Replace("[" + $_ + ".Host]", $NewMiner.Pools[$_].Host).`
            Replace("[" + $_ + ".Port]", $NewMiner.Pools[$_].Port).`
            Replace("[" + $_ + ".User]", $NewMiner.Pools[$_].User)
        }

        Add-Member -InputObject $NewMiner -MemberType NoteProperty -Name Process -Value (Start-Process $Miner_Path -ArgumentList $Miner_Arguments -PassThru -WorkingDirectory (Split-Path $Miner_Path))

        if($CurrentMiner -ne $null)
        {
            Stop-Process $CurrentMiner.Process
        }

        $CurrentMiner = $NewMiner
    }
    
    Sleep $Interval
}
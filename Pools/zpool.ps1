. .\Include.ps1

try
{
    $zpool_Request = Invoke-WebRequest "http://www.zpool.ca/api/status" -UseBasicParsing | ConvertFrom-Json
}
catch
{
    return
}

if(!$zpool_Request)
{
    return
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Locations = 'US'

$algos = $zpool_Request | Get-Member -Type NoteProperty | Select Name | Where {$_.Name -in 
                                                                                    "Cryptonight",
                                                                                    "Equihash",
                                                                                    "Ethash",
                                                                                    "Groestl",
                                                                                    "Keccak",
                                                                                    "Lyra2RE2",
                                                                                    "Lyra2z",
                                                                                    "Myriad-Groestl",
                                                                                    "NeoScrypt",
                                                                                    "Quibit",
                                                                                    "Scrypt",
                                                                                    "Sia",
                                                                                    "Skein",
                                                                                    "X11",
                                                                                    "Yescrypt",
                                                                                    "Lbry",
                                                                                    "Decred",
                                                                                    "Sib"}

$algos | foreach { 
	$Algorithm = $zpool_Request."$($_.name)".name
	$Coin = (Get-Culture).TextInfo.ToTitleCase(($zpool_Request."$($_.name)".name -replace "-", " ")) -replace " "
	
    #Switch Profit calculation based on algo.
	switch ("$($_.name)")
        {
            'equihash' 
                {
                    $Stat = Set-Stat -Name "$($Name)_$($Algorithm)_Profit" -Value ([decimal]$zpool_Request.$Algorithm.estimate_current/1000)
                    $Price = (($Stat.Live*(1-[Math]::Min($Stat.Day_Fluctuation,1)))+($Stat.Day*(0+[Math]::Min($Stat.Day_Fluctuation,1)))) 
                }
            'decred' 
                {
                    $Stat = Set-Stat -Name "$($Name)_$($Algorithm)_Profit" -Value ([decimal]$zpool_Request.$Algorithm.estimate_current/1000000000)
                    $Price = (($Stat.Live*(1-[Math]::Min($Stat.Day_Fluctuation,1)))+($Stat.Day*(0+[Math]::Min($Stat.Day_Fluctuation,1)))) 
                }
            default
                {
                    $Stat = Set-Stat -Name "$($Name)_$($Algorithm)_Profit" -Value ([decimal]$zpool_Request.$Algorithm.estimate_current/1000000)
                    $Price = (($Stat.Live*(1-[Math]::Min($Stat.Day_Fluctuation,1)))+($Stat.Day*(0+[Math]::Min($Stat.Day_Fluctuation,1)))) 
                }
        }
	
	
	[PSCustomObject]@{
		Algorithm = $Algorithm
		Info = $Coin
		Price = $Price
		StablePrice = $Stat.Week
		Protocol = 'stratum+tcp'
		Host = 'mine.zpool.ca'
		Port = $zpool_Request."$($_.name)".port
		User = $Wallet
		Pass = 'x'
		Location = $Locations
		SSL = $false
	}
}

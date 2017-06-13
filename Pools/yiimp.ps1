. .\Include.ps1

try
{
    $YiiMP_Request = Invoke-WebRequest "http://yiimp.ccminer.org/api/currencies" -UseBasicParsing | ConvertFrom-Json
}
catch
{
    return
}

if(-not $YiiMP_Request){return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Location = "US"

$YiiMP_Wallets = [PSCustomObject]@{
					AuroraCoin 		= ''		#skein
					Doubloon 		= ''		#hmq1725
					BitSend 		= ''		#xevan
					BitCore 		= ''		#bitcore
					Chaincoin 		= ''		#c11
					Decred 			= ''		#decred
					Digibyte 		= ''		#skein
					Feathercoin 	= ''		#neoscrypt
					Groestlcoin		= ''		#groestl
					Honey		 	= ''		#blake2s
					Hush 			= ''		#equihash
					JoinCoin 		= ''		#whirlpool
					Komodo 			= ''		#equihash
					LBRYCredits		= ''		#lbry
					MachineCoin 	= ''		#timetravel
					Neva 			= ''		#blake2s
					OrbitCoin 		= ''		#neoscrypt
					SibCoin 		= ''		#sib
					TajCoin 		= ''		#blake2s
					Titcoin 		= ''		#sha256
					VertCoin 		= ''		#lyra2v2
					Solaris 		= ''		#nist5
					Revolver 		= ''		#x11evo
					Verge 			= ''		#x17
				}


$YiiMP_Request | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | foreach {
    $YiiMP_Host = "yiimp.ccminer.org"
    $YiiMP_Port = $YiiMP_Request.$_.port
    $YiiMP_Algorithm = Get-Algorithm $YiiMP_Request.$_.algo
    $YiiMP_Coin = Get-Algorithm $YiiMP_Request.$_.name

    $Divisor = 1000000000
	
    switch($YiiMP_Algorithm)
    {
        "equihash"{$Divisor /= 1000}
        "blake2s"{$Divisor *= 1000}
		"blakecoin"{$Divisor *= 1000}
        "decred"{$Divisor *= 1000}
    }

    if((Get-Stat -Name "$($Name)_$($YiiMP_Coin)_Profit") -eq $null){$Stat = Set-Stat -Name "$($Name)_$($YiiMP_Coin)_Profit" -Value ([Double]$YiiMP_Request.$_.estimate/$Divisor)}
    else{$Stat = Set-Stat -Name "$($Name)_$($YiiMP_Coin)_Profit" -Value ([Double]$YiiMP_Request.$_.estimate/$Divisor)}
	
    if($YiiMP_Wallets.$YiiMP_Coin)
    {
        [PSCustomObject]@{
            Algorithm = $YiiMP_Algorithm
            Info = $YiiMP_Coin
            Price = $Stat.Live
            StablePrice = $Stat.Week
            MarginOfError = $Stat.Fluctuation
            Protocol = "stratum+tcp"
            Host = $YiiMP_Host
            Port = $YiiMP_Port
            User = $YiiMP_Wallets.$YiiMP_Coin
            Pass = "$WorkerName"
            Location = $Location
            SSL = $false
        }
    }
}

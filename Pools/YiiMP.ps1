using module ..\Include.psm1

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$YiiMP_Request = [PSCustomObject]@{}

try {
    $YiiMP_Request = Invoke-RestMethod "http://api.yiimp.eu/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
    return
}

if (($YiiMP_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Warning "Pool API ($Name) returned nothing. "
    return
}

$YiiMP_Regions = "us"

#Wallet addresses need to be entered here.  Any without an address will be skipped.
$YiiMP_Wallets = [PSCustomObject]@{
	AuroraCoin   = ''
    BitSend      = ''
    BitCore      = ''
	Chaincoin    = ''
	CreativeCoin = ''
    Decred       = ''
    Denarius     = ''
    Digibyte     = ''
    Doubloon	 = ''
	Feathercoin  = ''
    GoByte		 = ''
	Groestlcoin  = ''
    Hshare		 = ''
	Hush         = ''
    LUXCoin		 = ''
	MachineCoin  = ''
    Neva         = ''
    OrbitCoin    = ''
    Revolver     = ''
    SibCoin      = ''
    TajCoin      = ''
    Titcoin      = ''
    VertCoin     = ''
    Verge        = ''
}

$YiiMP_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
    $YiiMP_Host = "yiimp.eu"
    $YiiMP_Port = $YiiMP_Request.$_.port
    $YiiMP_Algorithm = $YiiMP_Request.$_.algo
    $YiiMP_Algorithm_Norm = Get-Algorithm $YiiMP_Request.$_.algo
    $YiiMP_Coin = Get-Algorithm $YiiMP_Request.$_.name

    $Divisor = 1000000000

    switch ($YiiMP_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "keccak" {$Divisor *= 1000}
		"keccakc" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($YiiMP_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($YiiMP_Algorithm_Norm)_Profit" -Value ([Double]$YiiMP_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    else {$Stat = Set-Stat -Name "$($Name)_$($YiiMP_Algorithm_Norm)_Profit" -Value ([Double]$YiiMP_Request.$_.estimate / $Divisor) -Duration (New-TimeSpan -Days 1)}

    $YiiMP_Regions | ForEach-Object {
        $YiiMP_Region = $_
        $YiiMP_Region_Norm = Get-Region $YiiMP_Region

        if ($YiiMP_Wallets.$YiiMP_Coin) {
            [PSCustomObject]@{
                Algorithm     = $YiiMP_Algorithm_Norm
                Info          = $YiiMP_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$YiiMP_Host"
                Port          = $YiiMP_Port
                User          = $YiiMP_Wallets.$YiiMP_Coin
                Pass          = "$WorkerName"
                Region        = $YiiMP_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}

using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Alexis78hsr\ccminer-alexis.exe"
$Uri = "https://github.com/nemosminer/ccminer-hcash/releases/download/alexishsr/ccminer-hsr-alexis-x86-cuda8.7z"

$Port = 4068

$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
	"_blake2s"   = " -i 31,31,31" #Blake2s, Beaten by Ccminer-x11gost. Note: do not use Excavator, high rejects
	"blakecoin"  = "" #Blakecoin, fastest!
	"_c11"        = " -i 21.5,21.5,21" #C11 beaten by Ccminer-x11gost
	"_decred"    = "" #Decred, broken, invalid share
	"_hsr"        = " -i 21.5,21.5,21" # hsr, beaten by CcminerPalginHSR!
	"_keccak"    = " -m 2 -i 20" #Keccak beaten by CcminerXevan
	"_lbry"      = " -i 28" #Lbry beaten by ExcavatorNvidia6
	"lyra2v2"    = " -i 24.25,24.25,23" #Lyra2RE2, fastest, does not pay :-(
	"_myr-gr"    = "" #MyriadGroestl, beaten by CcminerKlaust817_CUDA91!
	"_neoscrypt" = "" #NeoScrypt, lower intensity is better, beaten by CcminerKlausT
	"_nist5"      = "" #Nist5, beaten by CcminerKlaust817_CUDA91
	"_sia"       = "" #Sia
	"_sib"        = " -i 21.5,20.5,20.5" #Sib / x11gost, beaten by Ccminer-x11gost
	"_skein"      = " -i 30,20,28.9" #Skein, where do my hashes go???
	"skein2"     = "" # Double Skein (Woodcoin)
	"vanilla"    = "" #BlakeVanilla
	"vcash"      = "" # Blake256-8rounds (XVC)
	"veltor"     = " -i 22" #Veltor, beaten by CcminerPalgin
	"whirlpool"  = "" # whirlpool (JoinCoin)
	"_x11evo"    = "" #X11evo
    "x17"        = " -i 21.5,21.4,20.8" # Fastest
    "_x17"        = " -i 21.,21.5,20.9" # Fastest
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Type = "NVIDIA"
$Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Devices | ForEach-Object {

	$Device = $_

	$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>}} | ForEach-Object {

		$Algorithm = Get-Algorithm($_)
		$Command =  $Commands.$_
		
		if ($Devices.count -gt 1) {
			$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)_$($Device.Device_Norm)"
			$Command = "$(Get-CommandPerDevice -Command "$Command" -Devices $Device.Devices) -d $($Device.Devices -join ',')"
			$Index = $Device.Devices -join ","
		}

		{while (Get-NetTCPConnection -State "Listen" -LocalPort $($Port) -ErrorAction SilentlyContinue){$Port++}} | Out-Null

        [PSCustomObject]@{
            Name         = $Name
            Type         = $Type
            Device       = $Device.Device
            Path         = $Path
            Arguments    = "-a $_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) -b $Port$Command$CommonCommands"
            HashRates    = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
            API          = "Ccminer"
            Port         = $Port
            Wrap         = $false
            URI          = $Uri
            PowerDraw    = $Stats."$($Name)_$($Algorithm)_PowerDraw".Week
            ComputeUsage = $Stats."$($Name)_$($Algorithm)_ComputeUsage".Week
            Pool         = "$($Pools.$Algorithm.Name)"
            Index        = $Index
        }
	}
	if ($Port) {$Port ++}
}
Sleep 0
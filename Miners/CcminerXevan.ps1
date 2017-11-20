using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-xevan\ccminer_x86.exe"
$Uri = "https://github.com/nemosminer/ccminer-xevan/releases/download/ccminer-xevan/ccminer_x86.7z"

$Commands = [PSCustomObject]@{
	"blake2s"	= ""
	"blakecoin"	= "" # For GTX 1080ti " -i 31"
	"c11"		= "" # For GTX 1080ti " -i 21"
	"decred"	= ""
	"keccak"	= "" # For GTX 1080ti " -i 31 -m 2"
	"lbry"		= ""
	"lyra2v2"	= "" # For GTX 1080ti " -i 24"
	"myr-gr"	= "" # For GTX 1080ti " -i 24"
	"neoscrypt"	= "" # For GTX 1080ti " -i 22"
	"nist5"		= ""
	"quark"		= ""
	"qubit"		= ""
	"sia"		= ""  
	"sib"		= "" # For GTX 1080ti " -i 21"
	"skein"		= "" # For GTX 1080ti " -i 30"
	"veltor"	= "" # For GTX 1080ti " -i 22"
	"x11"		= "" # For GTX 1080ti " -i 21" 
	"x11evo"	= "" # For GTX 1080ti " -i 21" 
	"x13"		= "" 
	"x14"		= "" # For GTX 1080ti " -i 21" 
	"x15"		= "" # For GTX 1080ti " -i 20" 
	"xevan"		= "" # For GTX 1080ti & GTX 1060 3gb: " -i 21.5,18"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$Pools.$(Get-Algorithm($_)).Name -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>} } | ForEach-Object {

	$Algorithm = Get-Algorithm($_)

	[PSCustomObject]@{
		Type		= "NVIDIA"
		Path		= $Path
		Arguments	= "-a $_ -o stratum+tcp://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass)$($Commands.$_)"
		HashRates	= [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
		API			= "Ccminer"
		Port		= 4068
		Wrap		= $false
		URI			= $Uri
	}
}
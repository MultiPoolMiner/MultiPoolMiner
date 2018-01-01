using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-DSTM\zm.exe"
# Uri = "https://bitcointalk.org/index.php?topic=2021765.0"

$Port = 2222

# Custom command to be applied to all algorithms
$CommonCommands = ""

$Commands = [PSCustomObject]@{
    #"bitcore"      = "" #Bitcore
    #"blake2s"      = "" #Blake2s
    #"blakecoin"    = "" #Blakecoin
    #"vanilla"      = "" #BlakeVanilla
    #"cryptonight"  = "" #Cryptonight
    #"decred"       = "" #Decred
    "equihash"      = "" #Equihash
    #"ethash"       = "" #Ethash
    #"groestl"      = "" #Groestl
    #"hmq1725"      = "" #hmq1725
    #"keccak"       = "" #Keccak
    #"lbry"         = "" #Lbry
    #"lyra2v2"      = "" #Lyra2RE2
    #"lyra2z"       = "" #Lyra2z
    #"myr-gr"       = "" #MyriadGroestl
    #"neoscrypt"    = "" #NeoScrypt
    #"nist5"        = "" #Nist5
    #"pascal"       = "" #Pascal
    #"qubit"        = "" #Qubit
    #"scrypt"       = "" #Scrypt
    #"sia"          = "" #Sia
    #"sib"          = "" #Sib
    #"skein"        = "" #Skein
    #"timetravel"   = "" #Timetravel
    #"x11"          = "" #X11
    #"x11evo"       = "" #X11evo
    #"x17"          = "" #X17
    #"yescrypt"     = "" #Yescrypt
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Type = "NVIDIA"
$Devices = ($GPUs | Where {$Type -contains $_.Type}).Device
$Devices | ForEach-Object {
    $Device = $_

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where {$_ -cnotmatch "^_.+" -and $Pools.$(Get-Algorithm($_)).Name -and {$Pools.$(Get-Algorithm($_)).Protocol -eq "stratum+tcp" <#temp fix#>}} | ForEach-Object {

        $Algorithm = Get-Algorithm($_)
        $Command = $Commands.$_

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
            Arguments    = "--telemetry=127.0.0.1:$Port --server $($Pools.$Algorithm.Host) --port $($Pools.$Algorithm.Port) --user $($Pools.$Algorithm.User) --pass $($Pools.$Algorithm.Pass) $Command $CommonCommands"
            HashRates    = [PSCustomObject]@{$Algorithm = ($Stats."$($Name)_$($Algorithm)_HashRate".Week)}
            API          = "DSTM"
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
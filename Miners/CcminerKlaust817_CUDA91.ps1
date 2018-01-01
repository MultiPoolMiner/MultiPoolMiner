using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-KlausT817_CUDA91\ccminer.exe"
$Uri = "https://github.com/KlausT/ccminer/releases/download/8.17/ccminer-817-cuda91-x64.zip"

$Port = 4068

# Custom command to be applied to all algorithms
$CommonCommands = ""

# Uncomment defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    "blakecoin"     = "" # my best values for 1080ti/1070/10603G " -i 31,31,31" #Blakecoin, beaten by CcminerAlexis78hsr
    "c11"		    = "" # my best values for 1080ti/1070/10603G " -i 22,22,22" #C11 beaten by CcminerAlexis78hsr 
    "groestl"	    = "" # my best values for 1080ti/1070/10603G " -i 26,25,25" #Groestl, fastest
    "keccak"	    = "" # my best values for 1080ti/1070/10603G " -i 31,30,29.5" #Keccak
    "lyra2v2"	    = "" #Lyra2RE2, baten by Ccminer-x11gost
    "myr-gr"	    = "" # my best values for 1080ti/1070/10603G " -i 26,24,24" #MyriadGroestl, fastest
    "neoscrypt"	    = "" # my best values for 1080ti/1070/10603G " -i 21,16,16" #NeoScrypt, beaten by PalginNeoscrypt
    "nist5"	        = "" # my best values for 1080ti/1070/10603G " -i 26,26,25" #Nist5, beaten by Ccminer-x11gost
    "sia"		    = "" #Sia
    "skein"	        = "" # my best values for 1080ti/1070/10603G " -i 30,20,28.9" #Skein, beaten by Ccminer-x11gost
    "_X17"          = "" #beaten by CcminerAlexis78hsr
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
            Arguments    = "-a $_ -o $($Pools.$Algorithm.Protocol)://$($Pools.$Algorithm.Host):$($Pools.$Algorithm.Port) -u $($Pools.$Algorithm.User) -p $($Pools.$Algorithm.Pass) -b $Port $Command $CommonCommands"
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
using module ..\Include.psm1

$Path = ".\Bin\Lyra2z-NVIDIA\ccminer.exe"
$Uri = "https://github.com/djm34/ccminer-msvc2015/releases/download/v0.3.0/ccminer.rar"

# Custom command to be applied to all algorithms
$CommonCommands = ""

$Commands = [PSCustomObject]@{
    "lyra2h" = "" #Lyra2h
    "lyra2z" = "" #Lyra2z
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 4001 + 40 * $ItemCounter
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

        while ([Bool](Get-NetTCPConnection -State "Listen" -LocalPort $Port -ErrorAction SilentlyContinue)) {$Port++}

        [PSCustomObject]@{
            Name         = $Name
            Type         = $Device.Type
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
using module ..\Include.psm1

$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
#$Uri = "https://mega.nz/#F!O4YA2JgD!n2b4iSHQDruEsYUvTQP5_w"

$Fee = 0.98

#Custom command to be applied to all algorithms
$CommonCommands = ""

# Prefix defunct or outpaced algorithms with _ (do not use # to distinguish from default config)
$Commands = [PSCustomObject]@{
    "ethash"                                     = ""
    "ethash2gb"                                  = ""
    "ethash;blake2s;-dcoin blake2s -dcri 40"     = ""
    "ethash;blake2s;-dcoin blake2s -dcri 60"     = ""
    "ethash;blake2s;-dcoin blake2s -dcri 80"     = ""
    "ethash;decred;-dcoin dcr -dcri 100"         = ""
    "ethash;decred;-dcoin dcr -dcri 130"         = ""
    "ethash;decred;-dcoin dcr -dcri 160"         = ""
    "ethash;keccak;-dcoin keccak -dcri 70"       = ""
    "ethash;keccak;-dcoin keccak -dcri 90"       = ""
    "ethash;keccak;-dcoin keccak -dcri 110"      = ""
    "ethash;lbry;-dcoin lbc -dcri 60"            = ""
    "ethash;lbry;-dcoin lbc -dcri 75"            = ""
    "ethash;lbry;-dcoin lbc -dcri 90"            = ""
    "ethash;pascal;-dcoin pasc -dcri 40"         = ""
    "ethash;pascal;-dcoin pasc -dcri 60"         = ""
    "ethash;pascal;-dcoin pasc -dcri 80"         = ""
    "ethash;pascal;-dcoin pasc -dcri 100"        = ""
    "ethash2gb;blake2s;-dcoin blake2s -dcri 75"  = ""
    "ethash2gb;blake2s;-dcoin blake2s -dcri 100" = ""
    "ethash2gb;blake2s;-dcoin blake2s -dcri 125" = ""
    "ethash2gb;decred;-dcoin dcr -dcri 100"      = ""
    "ethash2gb;decred;-dcoin dcr -dcri 130"      = ""
    "ethash2gb;decred;-dcoin dcr -dcri 160"      = ""
    "ethash2gb;keccak;-dcoin keccak -dcri 70"    = ""
    "ethash2gb;keccak;-dcoin keccak -dcri 90"    = ""
    "ethash2gb;keccak;-dcoin keccak -dcri 110"   = ""
    "ethash2gb;lbry;-dcoin lbc -dcri 60"         = ""
    "ethash2gb;lbry;-dcoin lbc -dcri 75"         = ""
    "ethash2gb;lbry;-dcoin lbc -dcri 90"         = ""
    "ethash2gb;pascal;-dcoin pasc -dcri 40"      = ""
    "ethash2gb;pascal;-dcoin pasc -dcri 60"      = ""
    "ethash2gb;pascal;-dcoin pasc -dcri 80"      = ""
}

$Port = 4001 + 40 * $ItemCounter
$Type = "NVIDIA"
$Devices = ($GPUs | Where-Object {$Type -contains $_.Type}).Device
$Devices | ForEach-Object {
    $Device = $_

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$_ -cnotmatch "^_.+"} | ForEach-Object {

        $Command = $Commands.$_
        $MainAlgorithm = $_.Split(";") | Select -Index 0
        $MainAlgorithm_Norm = Get-Algorithm($MainAlgorithm)
        $DcriCmd = $_.Split(";") | Select -Index 2
        if ($DcriCmd) {
            $SecondaryAlgorithm = $_.Split(";") | Select -Index 1
            $SecondaryAlgorithm_Norm = Get-Algorithm($SecondaryAlgorithm)
            $Dcri = $DcriCmd.Split(" ") | Select -Index 3
        }
        else {
            $SecondaryAlgorithm = ""
            $SecondaryAlgorithm_Norm = ""
            $Dcri = ""
        }

        if ($Devices.count -gt 1) {
            $Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)-$($Device.Device_Norm)"
            $Command = "$(Get-CommandPerDevice -Command "$Command" -Devices $($Device.Devices)) -di $($Device.Devices -join '')"
            $Index = $Device.Devices -join ','
        }
        else {
            $Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
        }

        if ($Pools.$($MainAlgorithm_Norm).Name -and -not $SecondaryAlgorithm) {
            $Name = "$($Name)_$($MainAlgorithm_Norm)"
            [PSCustomObject]@{
                Name         = $Name
                Type         = $Device.Type
                Device       = $Device.Device
                Path         = $Path
                Arguments    = ("-mode 1 -mport -$Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins 1 -platform 2 $Command $CommonCommands").trim()
                HashRates    = [PSCustomObject]@{"$MainAlgorithm_Norm" = ($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week * $Fee)} 
                API          = "Claymore"
                Port         = $Port
                URI          = $Uri
                PowerDraw    = $Stats."$($Name)_$($MainAlgorithm_Norm)_PowerDraw".Week
                ComputeUsage = $Stats."$($Name)_$($MainAlgorithm_Norm)_ComputeUsage".Week
                Pool         = $($Pools.$MainAlgorithm_Norm.Name)
                Index        = $Index			
            }
        }
        if ($Pools.$($MainAlgorithm_Norm).Name -and $Pools.$($SecondaryAlgorithm_Norm).Name) {
            $Name = "$($Name)_$($SecondaryAlgorithm_Norm)$($Dcri)"
            [PSCustomObject]@{
                Name         = $Name
                Type         = $Device.Type
                Device       = $Device.Device
                Path         = $Path
                Arguments    = ("-mode 0 -mport -$Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins exp -dpool $($Pools."$SecondaryAlgorithm_Norm".Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass) -platform 2 $($DcriCmd) $Command $CommonCommands").trim()
                HashRates    = [PSCustomObject]@{"$MainAlgorithm_Norm" = ($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week * $Fee); "$SecondaryAlgorithm_Norm" = ($Stats."$($Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week * $Fee)}
                API          = "Claymore"
                Port         = $Port
                URI          = $Uri
                PowerDraw    = $Stats."$($Name)_$($MainAlgorithm_Norm)$($SecondaryAlgorithm_Norm)_PowerDraw".Week
                ComputeUsage = $Stats."$($Name)_$($MainAlgorithm_Norm)$($SecondaryAlgorithm_Norm)_ComputeUsage".Week
                Pool         = $($Pools.$MainAlgorithm_Norm.Name)
                Index        = $Index
            }
            if ($SecondaryAlgorithm_Norm -eq "Sia" -or $SecondaryAlgorithm_Norm -eq "Decred") {
                $SecondaryAlgorithm_Norm = "$($SecondaryAlgorithm_Norm)NiceHash"
                [PSCustomObject]@{
                    Name         = $Name
                    Type         = $Device.Type
                    Device       = $Device.Device
                    Path         = $Path
                    Arguments    = ("-mode 0 -mport -$Port -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -esm 3 -allpools 1 -allcoins exp -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass) -platform 2 $($DcriCmd) $Command $CommonCommands").trim()
                    HashRates    = [PSCustomObject]@{"$MainAlgorithm_Norm" = ($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week * $Fee); "$SecondaryAlgorithm_Norm" = ($Stats."$($Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week * $Fee)}
                    API          = "Claymore"
                    Port         = $Port
                    URI          = $Uri
                    PowerDraw    = $Stats."$($Name)_$($MainAlgorithm_Norm)$($SecondaryAlgorithm_Norm)_PowerDraw".Week
                    ComputeUsage = $Stats."$($Name)_$($MainAlgorithm_Norm)$($SecondaryAlgorithm_Norm)_ComputeUsage".Week
                    Pool         = $($Pools.$MainAlgorithm_Norm.Name)
                    Index        = $Index
                }
            }
        }
    }
    if ($Port) {$Port ++}
}
Sleep 0
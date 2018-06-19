using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\ExcavatorNHMP\excavator.exe"
$HashSHA256 = "AFE070E64EE06660218A8241B54A6A199FB1CE4F358A65CED3BFC38EF623EC4E"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.5.5a/excavator_v1.5.5a_NVIDIA_Win64.zip"
$UriManual = "https://github.com/nicehash/excavator/releases"
$Port = "5400"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "blake2s"; Threads = 1; Params = @(); MinMem = 2000000000} #Blake2s
    [PSCustomObject]@{Algorithm = "cryptonightV7"; Threads = 1; Params = @(); MinMem = 4000000000} #CryptonightV7
    [PSCustomObject]@{Algorithm = "daggerhashimoto"; Threads = 1; Params = @(); MinMem = 4000000000} #Ethash
    [PSCustomObject]@{Algorithm = "equihash"; Threads = 1; Params = @(); MinMem = 2000000000} #Equihash
    [PSCustomObject]@{Algorithm = "lbry"; Threads = 1; Params = @(); MinMem = 2000000000} #Lbry
    [PSCustomObject]@{Algorithm = "lyra2rev2"; Threads = 1; Params = @(); MinMem = 2000000000} #Lyra2RE2
    [PSCustomObject]@{Algorithm = "lyra2z"; Threads = 1; Params = @(); MinMem = 2000000000} #Lyra2z
    [PSCustomObject]@{Algorithm = "neoscrypt"; Threads = 1; Params = @(); MinMem = 2000000000} #NeoScrypt
    [PSCustomObject]@{Algorithm = "daggerhashimoto_decred"; Threads = 1; Params = @(); MinMem = 4000000000} #Dual mining 1 thread
    [PSCustomObject]@{Algorithm = "daggerhashimoto_pascal"; Threads = 1; Params = @(); MinMem = 4000000000} #Dual mining 1 thread
    [PSCustomObject]@{Algorithm = "daggerhashimoto_sia"; Threads = 1; Params = @(); MinMem = 4000000000} #Dual mining 1 thread
    [PSCustomObject]@{Algorithm = "blake2s"; Threads = 2; Params = @(); MinMem = 2000000000} #Blake2s
    [PSCustomObject]@{Algorithm = "cryptonightV7"; Threads = 2; Params = @(); MinMem = 12000000000} #CryptonightV7
    [PSCustomObject]@{Algorithm = "daggerhashimoto"; Threads = 2; Params = @(); MinMem = 4000000000} #Ethash
    [PSCustomObject]@{Algorithm = "equihash"; Threads = 2; Params = @(); MinMem = 2000000000} #Equihash
    [PSCustomObject]@{Algorithm = "lbry"; Threads = 2; Params = @(); MinMem = 2000000000} #Lbry
    [PSCustomObject]@{Algorithm = "lyra2rev2"; Threads = 2; Params = @(); MinMem = 2000000000} #Lyra2RE2
    [PSCustomObject]@{Algorithm = "lyra2z"; Threads = 2; Params = @(); MinMem = 2000000000} #Lyra2z
    [PSCustomObject]@{Algorithm = "neoscrypt"; Threads = 2; Params = @(); MinMem = 12000000000} #NeoScrypt
    [PSCustomObject]@{Algorithm = "daggerhashimoto_decred"; Threads = 2; Params = @(); MinMem = 4000000000} #Dual mining 2 threads
    [PSCustomObject]@{Algorithm = "daggerhashimoto_pascal"; Threads = 2; Params = @(); MinMem = 4000000000} #Dual mining 2 threads
    [PSCustomObject]@{Algorithm = "daggerhashimoto_sia"; Threads = 2; Params = @(); MinMem = 4000000000} #Dual mining 2 threads

    #ASIC mining only 2018/06/11
    #[PSCustomObject]@{Algorithm = "decred"; Threads = 1; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "decred"; Threads = 2; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "keccak"; Threads = 1; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "keccak"; Threads = 2; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "pascal"; Threads = 1; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "pascal"; Threads = 2; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "sia"; Threads = 1; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "sia"; Threads = 2; Params = @()} #Pascal
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | ForEach-Object {
        $Algorithm = $_.Algorithm
        $MinMem = $_.MinMem
        $Main_Algorithm = $Algorithm -Split "_" | Select-Object -Index 0
        $Main_Algorithm_Norm = "$(Get-Algorithm $Main_Algorithm)-NHMP"
        $Secondary_Algorithm = $Algorithm -Split "_" | Select-Object -Index 1
        $Secondary_Algorithm_Norm = "$(Get-Algorithm $Secondary_Algorithm)-NHMP"
        $Threads = $_.Threads
        $Params = $_.Params

        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMem} )

        if ($Pools.$Main_Algorithm_Norm.Name -eq "Nicehash" -and $Miner_Device) {

            if (-not $Secondary_Algorithm) {
                #Single algo mining
                $Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                [PSCustomObject]@{
                    Name             = $Miner_Name
                    DeviceName       = $Miner_Device.Name
                    Path             = $Path
                    HashSHA256       = $HashSHA256

                    Arguments        = @(`
                        [PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port)"; "$($Pools.$Main_Algorithm_Norm.User)")},`
                        [PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Main_Algorithm")},`
                        [PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($Miner_Device.Type_PlatformId_Index | ForEach-Object {@("alg-$($Algorithm)", "$_") + $Params} | Select-Object) * $Threads)}
                    )
                    HashRates        = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                    API              = "ExcavatorNHMP"
                    Port             = $Miner_Port
                    URI              = $Uri
                    PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                    PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                }
            }
            else {
                #Dual algo mining
                if ($Pools.$Secondary_Algorithm_Norm.Host -and $Pools.$Secondary_Algorithm_Norm.Name -eq "Nicehash" ) {
                    $Miner_Name = (@($Name) + @("$Secondary_Algorithm_Norm") + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                    [PSCustomObject]@{
                        Name             = $Miner_Name
                        DeviceName       = $Miner_Device.Name
                        Path             = $Path
                        HashSHA256       = $HashSHA256
                        Arguments        = @(`
                            [PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port)"; "$($Pools.$Main_Algorithm_Norm.User)")},`
                            [PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Main_Algorithm")};[PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Secondary_Algorithm")},`
                            [PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($Miner_Device.Type_PlatformId_Index | ForEach-Object {@("alg-$($Algorithm)", "$_") + $Params} | Select-Object) * $Threads)}
                        )
                        HashRates        = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                        API              = "ExcavatorNHMP"
                        Port             = $Miner_Port
                        URI              = $Uri
                        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                        PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                    }
                }
            }
        }
    }
}

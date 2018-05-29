using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Type = "NVIDIA"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Path = ".\Bin\Excavator\excavator.exe"
$HashSHA256 = "4CC2FF8C07F17E940A1965B8D0F7DD8508096A4E4928704912FA96C442346642"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.4.4a/excavator_v1.4.4a_NVIDIA_Win64.zip"

$Commands = [PSCustomObject]@{
    "daggerhashimoto:1"        = @("") #Ethash 1 thread
    "equihash:1"               = @("") #Equihash 1 thread
    "neoscrypt:1"              = @("") #NeoScrypt 1 thread
    "keccak:1"                 = @("") #Keccak 1 thread
    "lbry:1"                   = @("") #Lbry 1 thread
    "lyra2rev2:1"              = @("") #Lyra2RE2 1 thread
    "daggerhashimoto:2"        = @("") #Ethash 2 threads
    "equihash:2"               = @("") #Equihash 2 threads
    "keccak:2"                 = @("") #Keccak 2 threads
    "lbry:2"                   = @("") #Lbry 2 threads
    "lyra2rev2:2"              = @("") #Lyra2RE2 2 threads
    #"neoscrypt:2"             = @("") #NeoScrypt 2 threads; out of memory
    "daggerhashimoto_decred:1" = @("") #Dual mining 1 tread
    "daggerhashimoto_pascal:1" = @("") #Dual mining 1 tread
    "daggerhashimoto_sia:1"    = @("") #Dual mining 1 tread
    "daggerhashimoto_decred:2" = @("") #Dual mining 2 treads
    "daggerhashimoto_pascal:2" = @("") #Dual mining 2 treads
    "daggerhashimoto_sia:2"    = @("") #Dual mining 2 treads

    # ASIC - never profitable 25/05/2018
    #"blake2s:1"                = @("") #Blake2s 1 thread
    #"pascal:1"                 = @("") #Pascal 1 threads
    #"blake2s:2"                = @("") #Blake2s 2 thread
    #"pascal:2"                 = @("") #Pascal 2 threads
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3456 + (2 * 10000)

$DeviceIDs = @($Devices.$Type.DeviceIDs)

if (-not ($DeviceIDs.Count -or $Config.InfoOnly))  {return}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$_ -match ".+:[1-9]"} | ForEach-Object {

    $Main_Algorithm = $_.Split(":") | Select-Object -Index 0
    $Threads =  $_ -split ":" | Select -Index 1

    if ($Main_Algorithm -match "^.+_.+$") {
        # Dual algo mining
        $Main_Algorithm_Norm = Get-Algorithm ($Main_Algorithm.Split("_") | Select-Object -Index 0)
        $Secondary_Algorithm_Norm = Get-Algorithm ($Main_Algorithm.Split("_") | Select-Object -Index 1)
        $Miner_Name = "$($Name)$($Main_Algorithm_Norm)$($Secondary_Algorithm_Norm)$($Threads)"
        if ($Pools.$Main_Algorithm_Norm.Host -and $Pools.$Secondary_Algorithm_Norm.Host) {
            [PSCustomObject]@{
                Name             = $Miner_Name
                Type             = "NVIDIA"
                Path             = $Path
                HashSHA256       = $HashSHA256
                Arguments        = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Main_Algorithm", "$([Net.DNS]::Resolve($Pools.$Main_Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Main_Algorithm_Norm.Port)", "$($Pools.$Main_Algorithm_Norm.User):$($Pools.$Main_Algorithm_Norm.Pass)", "$([Net.DNS]::Resolve($Pools.$Secondary_Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Secondary_Algorithm_Norm.Port)", "$($Pools.$Secondary_Algorithm_Norm.User):$($Pools.$Secondary_Algorithm_Norm.Pass)")}) + @([PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($DeviceIDs | ForEach-Object {@("alg-0", "$_", $(if ($Commands.$_) {"$($Commands.$_)"}))} | Select-Object) * $Threads)})
                HashRates        = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                API              = "Excavator"
                Port             = $Port
                URI              = $Uri
                PrerequisitePath = "$env:SystemRoot\System32\msvcp140.dll"
                PrerequisiteURI  = "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe"
            }
        }
    }
    else {
        # Single algo mining
        $Main_Algorithm_Norm = Get-Algorithm $Main_Algorithm
        $Miner_Name = "$($Name)$($Threads)"
        if ($Pools.$Main_Algorithm_Norm.Host) {
            [PSCustomObject]@{
                Name             = $Miner_Name
                Type             = "NVIDIA"
                Path             = $Path
                HashSHA256       = $HashSHA256
                Arguments        = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Main_Algorithm", "$([Net.DNS]::Resolve($Pools.$Main_Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Main_Algorithm_Norm.Port)", "$($Pools.$Main_Algorithm_Norm.User):$($Pools.$Main_Algorithm_Norm.Pass)")}) + @([PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($DeviceIDs | ForEach-Object {@("alg-0", "$_", $(if ($Commands.$_) {"$($Commands.$_)"}))} | Select-Object) * $Threads)})
                HashRates        = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                API              = "Excavator"
                Port             = $Port
                URI              = $Uri
                PrerequisitePath = "$env:SystemRoot\System32\msvcp140.dll"
                PrerequisiteURI  = "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe"
            }
        }
    }
}
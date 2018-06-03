using module ..\Include.psm1

$Path = ".\Bin\Excavator\excavator.exe"
$HashSHA256 = "4CC2FF8C07F17E940A1965B8D0F7DD8508096A4E4928704912FA96C442346642"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.4.4a/excavator_v1.4.4a_NVIDIA_Win64.zip"

$Commands = [PSCustomObject]@{
    "daggerhashimoto:1" = @() #Ethash 1 thread
    "equihash:1"        = @() #Equihash 1 thread
    "neoscrypt:1"       = @() #NeoScrypt 1 thread
    "lbry:1"            = @() #Lbry 1 thread
    "lyra2rev2:1"       = @() #Lyra2RE2 1 thread
    "pascal:1"          = @() #Pascal 1 thread
    "daggerhashimoto:2" = @() #Ethash 2 threads
    "equihash:2"        = @() #Equihash 2 threads
    #"neoscrypt:2"       = @() #NeoScrypt 2 threads; out of memory
    "lbry:2"            = @() #Lbry 2 threads
    "lyra2rev2:2"       = @() #Lyra2RE2 2 threads
    "pascal:2"          = @() #Pascal 2 threads
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3456 + (2 * 10000)

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {($Devices -or $Config.InfoOnly) -and $_ -match ".+:[1-9]"} | ForEach-Object {
    $Algorithm = $_.Split(":") | Select-Object -Index 0
    $Algorithm_Norm = Get-Algorithm $Algorithm

    $Threads = $_ -split ":" | Select-Object -Index 1
    $Miner_Name = (@($Name) + @($Devices | Sort-Object Type, Type_Index | ForEach-Object {"{0}#{1:d2}" -f $_.Type, $_.Type_Index}) | Select-Object) -join '-'

    if ($Pools.$Algorithm_Norm.Host) {
        [PSCustomObject]@{
            Name             = $Miner_Name
            Device           = $Devices
            Path             = $Path
            HashSHA256       = $HashSHA256
            Arguments        = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Algorithm", "$([Net.DNS]::Resolve($Pools.$Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Algorithm_Norm.Port)", "$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)")}) + @([PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($Devices.Type_PlatformId_Index | ForEach-Object {@("alg-0", "$_")} | Select-Object) * $Threads) + $Commands.$_})
            HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API              = "Excavator"
            Port             = $Port
            URI              = $Uri
            PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
            PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
        }
    }
}
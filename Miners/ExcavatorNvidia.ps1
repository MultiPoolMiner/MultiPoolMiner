using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

# Hardcoded per miner version, do not allow user to change in config
$MinerFileVersion = "2018032200" #Format: YYYYMMDD[TwoDigitCounter], higher value will trigger config file update
$MinerBinaryInfo =  "NiceHash Excavator 1.4.4 alpha (x64)"
$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\Excavator\excavator.exe"
$Type = "NVIDIA"
$API = "Nicehash"
$Uri = ""
$UriManual = "https://github.com/nicehash/excavator/releases/download/v1.4.4a/excavator_v1.4.4a_NVIDIA_Win64.zip"
$WebLink = "https://github.com/nicehash/excavator" # See here for more information about the miner
$PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
$PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"

# Create default miner config, required for setup
$DefaultMinerConfig = [PSCustomObject]@{
    "MinerFileVersion" = "$MinerFileVersion"
    "MinerBinaryInfo" = "$MinerBinaryInfo"
    "Uri" = "$Uri"
    "UriManual" = "$UriManual"    
    "Type" = "$Type"
    "Path" = "$Path"
    "Port" = 23456
    #"IgnoreHWModel" = @("GPU Model Name", "Another GPU Model Name", e.g "GeforceGTX1070") # Available model names are in $Devices.$Type.Name_Norm, Strings here must match GPU model name reformatted with (Get-Culture).TextInfo.ToTitleCase(($_.Name)) -replace "[^A-Z0-9]"
    "IgnoreHWModel" = @()
    #"IgnoreDeviceID" = @(0, 1) # Available deviceIDs are in $Devices.$Type.DeviceIDs
    "IgnoreDeviceID" = @()
    "Commands" = [PSCustomObject]@{
        "blake2s:1"         = @() #Blake2s 
        "cryptonight:1"     = @() #Cryptonight
        "decred:1"          = @() #Decred
        "daggerhashimoto:1" = @() #Ethash
        "equihash:1"        = @() #Equihash
        "neoscrypt:1"       = @() #NeoScrypt
        "nist5:1"           = @() #Nist5
        "keccak:1"          = @() #Keccak
        "lbry:1"            = @() #Lbry
        "lyra2rev2:1"       = @() #Lyra2RE2
        "pascal:1"          = @() #Pascal
        "blake2s:2"         = @() #Blake2s 
        "cryptonight:2"     = @() #Cryptonight
        "decred:2"          = @() #Decred
        "daggerhashimoto:2" = @() #Ethash
        "equihash:2"        = @() #Equihash
        "neoscrypt:2"       = @() #NeoScrypt
        "nist5:2"           = @() #Nist5
        "keccak:2"          = @() #Keccak
        "lbry:2"            = @() #Lbry
        "lyra2rev2:2"       = @() #Lyra2RE2
        "pascal:2"          = @() #Pascal
    }
    "CommonCommands" = ""
}

if (-not $Config.Miners.$Name.MinerFileVersion) {
    # Read existing config file, do not use $Config because variables are expanded (e.g. $Wallet)
    $NewConfig = Get-Content -Path 'config.txt' -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    # Apply default
    $NewConfig.Miners | Add-Member $Name $DefaultMinerConfig -Force
    # Save config to file
    $NewConfig | ConvertTo-Json -Depth 10 | Set-Content "config.txt" -Force -ErrorAction Stop
    # Apply config, must re-read from file to expand variables
    $Config = Get-ChildItemContent "Config.txt" -ErrorAction Stop | Select-Object -ExpandProperty Content
}
else {
    if ($MinerFileVersion -gt $Config.Miners.$Name.MinerFileVersion) {
        try {
            # Read existing config file, do not use $Config because variables are expanded (e.g. $Wallet)
            $NewConfig = Get-Content -Path 'Config.txt' | ConvertFrom-Json -InformationAction SilentlyContinue
            
            # Execute action, e.g force re-download of binary
            # Should be the first action. If it fails no further update will take place, update will be retried on next loop
            if ($Uri) {
                if (Test-Path $Path) {Remove-Item $Path -Force -Confirm:$false -ErrorAction Stop} # Remove miner binary to forece re-download
                # Remove benchmark files, could by fine grained to remove bm files for some algos
                # if (Test-Path ".\Stats\$($Name)_*_hashrate.txt") {Remove-Item ".\Stats\$($Name)_*_hashrate.txt" -Force -Confirm:$false -ErrorAction SilentlyContinue}
            }

            # Always update MinerFileVersion and download link, -Force to enforce setting
            $NewConfig.Miners.$Name | Add-member MinerFileVersion "$MinerFileVersion" -Force
            $NewConfig.Miners.$Name | Add-member Uri "$Uri" -Force

            # Remove config item if in existing config file, -ErrorAction SilentlyContinue to ignore errors if item does not exist
            $NewConfig.Miners.$Name | Foreach-Object {
                # e.g. $_.Commands.PSObject.Properties.Remove("ethash;pascal:-dcoin pasc -dcri 20")
            } -ErrorAction SilentlyContinue

            # Add config item if not in existing config file, -ErrorAction SilentlyContinue to ignore errors if item exists
            # e.g. $NewConfig.Miners.$Name.Commands | Add-Member "ethash;pascal:60" "" -ErrorAction SilentlyContinue

            # Save config to file
            $NewConfig | ConvertTo-Json -Depth 10 | Set-Content "Config.txt" -Force -ErrorAction Stop
            # Apply config, must re-read from file to expand variables
            $Config = Get-ChildItemContent "Config.txt" | Select-Object -ExpandProperty Content
        }
        catch {}
    }
}

if ($Info) {
    # Just return info about the miner for use in setup
    # attributes without a curresponding settings entry are read-only by the GUI, to determine variable type use .GetType().FullName
    return [PSCustomObject]@{
        MinerFileVersion = $MinerFileVersion
        MinerBinaryInfo  = $MinerBinaryInfo
        Uri              = $Uri
        UriInfo          = $UriManual
        Type             = $Type
        Path             = $Path
        Port             = $Port
        WebLink          = $WebLink
        Settings         = @(
            [PSCustomObject]@{
                Name        = "Uri"
                Controltype = "string"
                Default     = $DefaultMinerConfig.Uri
                Info        = "MPM automatically downloads the miner binaries from this link and unpacks them.`nFiles stored on Google Drive or Mega links cannot be downloaded automatically.`n"
                Tooltip     = "If Uri is blank or is not a direct download link the miner binaries must be downloaded and unpacked manually (see README). "
            }
            [PSCustomObject]@{
                Name        = "UriManual"
                Controltype = "string"
                Default     = $DefaultMinerConfig.UriManual
                Info        = "Due to NiceHash special EULA excavator must be downloaded and extracted manually.`nUnpack downloaded files to '$Path'."
                Tooltip     = "See README for manual download and unpack instruction."
            }
            [PSCustomObject]@{
                Name        = "IgnoreHWModel"
                Controltype = "string[]"
                Default     = $DefaultMinerConfig.IgnoreHWModel
                Info        = "List of hardware models you do not want to mine with this miner, e.g. 'GeforceGTX1070'.`nLeave empty to mine with all available hardware. "
                Tooltip     = "Detected $Type miner HW:`n$($Devices.$Type | ForEach-Object {"$($_.Name_Norm): DeviceIDs $($_.DeviceIDs -join ' ,')`n"})"
            }
            [PSCustomObject]@{
                Name        = "IgnoreDeviceID"
                Controltype = "int[]"
                Default     = $DefaultMinerConfig.IgnoreDeviceID
                Info        = "List of device IDs you do not want to mine with this miner, e.g. '0'.`nLeave empty to mine with all available hardware. "
                Tooltip     = "Detected $Type miner HW:`n$($Devices.$Type | ForEach-Object {"$($_.Name_Norm): DeviceIDs $($_.DeviceIDs -join ' ,')`n"})"
            }
            [PSCustomObject]@{
                Name        = "Commands"
                Controltype = "PSCustomObject"
                Default     = $DefaultMinerConfig.Commands
                Info        = "Each line defines an algorithm that can be mined with this miner.`nThe number of threads (default:1) are defined after the ':'.`nOptional miner parameters can be added after the '=' sign. "
                Tooltip     = "Note: Most extra parameters must be prefixed with a space"
            }
            [PSCustomObject]@{
                Name        = "CommonCommands"
                Controltype = "string"
                Default     = $DefaultMinerConfig.CommonCommands
                Info        = "Optional miner parameter that gets appended to the resulting miner command line (for all algorithms). "
                Tooltip     = "Note: Most extra parameters must be prefixed with a space"
            }
        )
    }
}

# Make sure miner binpath exists
if (-not (Test-Path (Split-Path $Path))) {New-Item (Split-Path $Path) -ItemType "directory" -ErrorAction Stop | Out-Null}

function Build-Miner {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm_Norm = ""
    )

    $JsonFile = "$($MinerName)_$($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_$($Type).json"

    if ($Pools.$Algorithm_Norm.Host) {
        [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Algorithm", "$([Net.DNS]::Resolve($Pools.$Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Algorithm_Norm.Port)", "$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)")})},
        [PSCustomObject]@{time = 1; commands = @($DeviceIDs | Foreach-Object {[PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$_") + $(if ($Commands) {$Commands}) + $(if($CommonCommands) {$CommonCommands})}}) * $Threads},
        [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})} | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($JsonFile)" -Force -ErrorAction Stop
    }
    [PSCustomObject]@{
        Name             = $MinerName
        Type             = $Type
        Path             = $Path
        Arguments        = "-p $MinerPort -c $JsonFile -na"
        HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($MinerName)_$($Algorithm_Norm)_HashRate".Week}
        API              = $Api
        Port             = $MinerPort
        URI              = $Uri
        PrerequisitePath = $PrerequisitePath
        PrerequisiteURI  = $PrerequisiteURI
        Fees             = @($null)
        Index            = $DeviceIDs -join ';'
    }
}

# Get device list
$Devices.$Type | Where-Object {$Config.Miners.IgnoreHWModel -inotcontains $_.Name_Norm -or $Config.Miners.$Name.IgnoreHWModel -inotcontains $_.Name_Norm} | ForEach-Object {
    
    if ($DeviceTypeModel -and -not $Config.MinerInstancePerCardModel) {return} #after first loop $DeviceTypeModel is present; generate only one miner
    $DeviceTypeModel = $_
    $DeviceIDs = @() # array of all devices with more than 3MiB VRAM, ids will be in hex format
    $DeviceIDs2gb = @() # array of all devices, ids will be in hex format

    # Get DeviceIDs, filter out all disabled hw models and IDs
    if ($Config.MinerInstancePerCardModel -and (Get-Command "Get-CommandPerDevice" -ErrorAction SilentlyContinue)) { # separate miner instance per hardware model
        if ($Config.Miners.IgnoreHWModel -inotcontains $DeviceTypeModel.Name_Norm -and $Config.Miners.$Name.IgnoreHWModel -inotcontains $DeviceTypeModel.Name_Norm) {
            $DeviceTypeModel.DeviceIDs | Where-Object {$Config.Miners.IgnoreDeviceID -notcontains $_ -and $Config.Miners.$Name.IgnoreDeviceID -notcontains $_} | ForEach-Object {
                $DeviceIDs2gb += [Convert]::ToString($_, 16) # convert id to hex
                if ($DeviceTypeModel.GlobalMemsize -ge 3000000000) {$DeviceIDs += [Convert]::ToString($_, 16)} # convert id to hex
            }
        }
    }
    else { # one miner instance per hw type
        $Devices.$Type | Where-Object {$Config.Miners.IgnoreHWModel -inotcontains $_.Name_Norm -and $Config.Miners.$Name.IgnoreHWModel -inotcontains $_.Name_Norm} | ForEach-Object {
            $_.DeviceIDs | Where-Object {$Config.Miners.IgnoreDeviceID -notcontains $_ -and $Config.Miners.$Name.IgnoreDeviceID -notcontains $_} | ForEach-Object {
                $DeviceIDs2gb += [Convert]::ToString($_, 16) # convert id to hex
                if ($_.GlobalMemsize -ge 3000000000) {$DeviceIDs += [Convert]::ToString($_, 16)} # convert id to hex
            }
        }
    }

    $Config.Miners.$Name.Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$_ -match ".+:[1-9]"} | ForEach-Object {

        $Algorithm = $_.Split(":") | Select -Index 0
        $Algorithm_Norm = Get-Algorithm $Algorithm
        
        $Threads = $_.Split(":") | Select -Index 1

        if ($Algorithm_Norm -eq "Ethash2gb") {
            $DeviceIDs = $DeviceIDs2gb
        }

        if ($Config.MinerInstancePerCardModel -and (Get-Command "Get-CommandPerDevice" -ErrorAction SilentlyContinue)) {
            $MinerName = "$Name$($Threads)-$($DeviceTypeModel.Name_Norm)"
            $Commands = Get-CommandPerDevice -Command $Config.Miners.$Name.Commands.$_ -Devices $DeviceIDs # additional command line options for main algorithm
        }
        else {
            $MinerName = "$($Name)$($Threads)"
            $Commands = $Config.Miners.$Name.Commands.$_ # additional command line options for main algorithm
        }    

        $MinerPort = $Config.Miners.$Name.Port + $Devices.$Type.IndexOf($DeviceTypeModel) # make port unique

        try {
            if ($Algorithm_Norm -ne "Decred" -and $Algorithm_Norm -ne "Sia") {
                Build-Miner -Algorithm_Norm $Algorithm_Norm
                if ($Algorithm -eq "daggerhashimoto") {Build-Miner -Algorithm_Norm "$($Algorithm_Norm)2gb"}
            }
            else {
                Build-Miner -Algorithm_Norm "$($Algorithm_Norm)NiceHash"
            }
        }
        catch {
        }
    }
}
Sleep 0
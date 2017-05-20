$ThreadIndex = 0
$Threads = 2

$Path = ".\Bin\Excavator\excavator.exe"
$Uri = 'https://github.com/nicehash/excavator/releases/download/v1.2.1a/excavator_v1.2.1a_Win64.zip'

if((Test-Path $Path) -eq $false)
{
    $FolderName_Old = ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName
    $FolderName_New = Split-Path (Split-Path $Path) -Leaf
    $FileName = "$FolderName_New$(([IO.FileInfo](Split-Path $Uri -Leaf)).Extension)"

    if(Test-Path $FileName){Remove-Item $FileName}
    if(Test-Path "$(Split-Path (Split-Path $Path))\$FolderName_New"){Remove-Item "$(Split-Path (Split-Path $Path))\$FolderName_New" -Recurse}
    if(Test-Path "$(Split-Path (Split-Path $Path))\$FolderName_Old"){Remove-Item "$(Split-Path (Split-Path $Path))\$FolderName_Old" -Recurse}

    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing
    Start-Process "7z" "x $FileName -o$(Split-Path (Split-Path $Path))\$FolderName_Old -y -spe" -Wait
    Rename-Item "$(Split-Path (Split-Path $Path))\$FolderName_Old" "$FolderName_New"
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    #Decred = 'decred'
    #Pascal = 'pascal'
    Equihash = 'equihash'
}

$Port = 3456+($ThreadIndex*10000)

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    $Config = Get-Content "$(Split-Path $Path)\default_command_file.json" | ConvertFrom-Json
    $Config[0].commands[0].params[0] = $Algorithms.$_
    $Config[0].commands[0].params[1] = "$($Pools.$_.Host):$($Pools.$_.Port)"
    $Config[0].commands[0].params[2] = "$($Pools.$_.User):$($Pools.$_.Pass)"
    $Config[1].commands = @(@{id = 1; method = "worker.add"; params = @("0","$ThreadIndex")})*$Threads
    ($Config | ConvertTo-Json -Depth 10) | Set-Content "$(Split-Path $Path)\$_$ThreadIndex.json"

    [PSCustomObject]@{
        Type = 'AMD','NVIDIA'
        Path = $Path
        Arguments = -Join ('-p ', $Port, ' -c ', $_, $ThreadIndex, '.json')
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Week)')}
        API = 'NiceHash'
        Port = $Port
        Wrap = $false
        URI = $Uri
        Device = 'GPU#{0:d2}' -f $ThreadIndex
    }
}
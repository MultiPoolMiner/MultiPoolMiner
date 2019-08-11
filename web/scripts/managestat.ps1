using module ..\..\Include.psm1

param(
    [PSCustomObject]$Parameters
)

$Parameters.Algorithms = $Parameters.Algorithms -replace ",undefined$"

$Count = [Int]0
$Text = ""

Switch ($Parameters.Action) {
    "Get" {
        #Get stat files for given miner name
        if ($Parameters.MinerName) {
            @($Parameters.Algorithms -split ",") | ForEach-Object {
                $Text +="`n$($Parameters.MinerName)_$($_)_$($Parameters.Type)`n"
            }
        }
        elseif ($Null -ne $Parameters.Value) {
            #Get stat files with given value
            $Files = Get-ChildItem "Stats\$($Parameters.Type)" | ForEach-Object {
                $FileName = $_.FullName
                $Stats = Get-Content $Filename | ConvertFrom-Json
                if ($Stats.Minute -eq $Parameters.Value) {
                    $Text += "`n$($_.Name -replace "_$($Parameters.Type).txt")"
                    $Count++
                }
            }
            if ($Count) {$Text += "`n"}
            if ($Parameters.Value -ne -1) {
                $Text += "`n$Count stat file$(if ($Count -ne 1) {"s"}) with $($Parameters.Value)$($Parameters.Unit) $($Parameters.Type). "
            }
            else {
                $Text += "`n$Count disabled miner$(if ($Count -ne 1) {"s"}). "
            }
        }
    }
    "Set" {
        #Set stat value to Parameters.Value
        # 0 = mark as failed
        #-1 = disabled
        if ($Null -ne $Parameters.Value) {
            @($Parameters.Algorithms -split ",") | ForEach-Object {
                $Stat = "$($Parameters.MinerName)_$($_)_$($Parameters.Type)"
                Remove-Item "Stats\$($Parameters.Type)\$($Stat).txt" -Force -ErrorAction SilentlyContinue
                Set-Stat -Name $Stat -Value $Parameters.Value -Duration ([TimeSpan]0)
                $Text += "`n$($Stat).txt"
                $Count++
            }
            if ($Count) {$Text += "`n"}
            $Text = "`nTo re-enable remove the stat file$(if ($Count -ne 1) {"s"}):`n$Text"
        }
    }
    "Remove" {
        #Remove stat files for given miner name
        if ($Parameters.MinerName) {
            @($Parameters.Algorithms -split ",") | ForEach-Object {
                $Stat = "$($Parameters.MinerName)_$($_)_$($Parameters.Type)"
                Remove-Item "Stats\$($Parameters.Type)\$($Stat).txt" -Force -ErrorAction SilentlyContinue
            }
            Switch ($Parameters.Type) {
                "HashRate"   {$Text = "The miner will re-benchmark on next run. "}
                "PowerUsage" {$Text = "The miner will re-measure power usage on next run. "}
                "Profit"     {$Text = "Pool data reset. "}
            }
        }
        elseif ($Null -ne $Parameters.Value) {
            #Remove stat files with given value
            $Files = Get-ChildItem "Stats\$($Parameters.Type)" | ForEach-Object {
                $FileName = $_.FullName
                $Stats = Get-Content $Filename | ConvertFrom-Json
                if ($Stats.Minute -eq $Parameters.Value) {
                    Remove-Item $FileName -Force -ErrorAction SilentlyContinue
                    $Text += "`n$($_.Name -replace "_$($Parameters.Type)")"
                    $Count++
                }
            }
            if ($Count) {$Text += "`n"}
            if ($Parameters.Value -ne -1) {            
                $Text += "`nRemoved $Count stat file$(if ($Count -ne 1) {"s"}) with $($Parameters.Value)$($Parameters.Unit) $($Parameters.Type). "
            }
            else {
                $Text += "`nRe-enabled $Count miner$(if ($Count -ne 1) {"s"}). "
            }
        }
        else {
            #Remove all stat files of type $Parameters.Type
            $Files = Get-ChildItem "Stats\$($Parameters.Type)"
            $Count = $Files.Count
            $Files | ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
            $Text = "`nRemoved $Count $($Parameters.Type) stat file$(if ($Count -ne 1) {"s"}). "
        }
    }
}

Write-Output "<pre>"
$Text | Write-Output
Write-Output "</pre>"
using module .\Include.psm1

param(
    [Parameter(Mandatory = $true)]
    [Int]$ControllerProcessID, 
    [Parameter(Mandatory = $true)]
    [String]$Id, 
    [Parameter(Mandatory = $true)]
    [String]$FilePath, 
    [Parameter(Mandatory = $false)]
    [String]$ArgumentList = "", 
    [Parameter(Mandatory = $false)]
    [String]$WorkingDirectory = "",
    [Parameter(Mandatory = $false)]
    [String]$ShowWindow = "SW_SHOWNORMAL",
    [Parameter(Mandatory = $false)]
    [String]$CreationFlags = "CREATE_NEW_CONSOLE",
    [Parameter(Mandatory = $false)]
    [Int]$ForegroundWindowID
    
)

if ($ForegroundWindowID -gt 0) {[Microsoft.VisualBasic.Interaction]::AppActivate($ForegroundWindowID)}

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Remove-Item ".\Wrapper\$Id.txt" -Force -ErrorAction Ignore

$Job = Start-Job -ArgumentList $FilePath, $ArgumentList, $WorkingDirectory {
    param($FilePath, $ArgumentList, $WorkingDirectory)
    if ($WorkingDirectory) {Set-Location $WorkingDirectory}
    if ($ArgumentList) {Invoke-Expression "& '$FilePath' $ArgumentList 2>&1"}
    else {Invoke-Expression "& '$FilePath' 2>&1"}
}

Write-Host "MultiPoolMiner Wrapper Started" -BackgroundColor Yellow -ForegroundColor Black

do {
    Start-Sleep 1

    $Job | Receive-Job | ForEach-Object {
        $Line = $_

        if (($Line -like "*total*" -or $Line -like "*accepted*") -and $Line -like "*/s*") {
            $Words = $Line -split " "

            $matches = $null

            if ($Words[$Words.IndexOf(($Words -like "*/s*" | Select-Object -Last 1))] -match "^((?:\d*\.)?\d+)(.*)$") {
                $HashRate = [Decimal]$matches[1]
                $HashRate_Unit = $matches[2]
            }
            else {
                $HashRate = [Decimal]$Words[$Words.IndexOf(($Words -like "*/s*" | Select-Object -Last 1)) - 1]
                $HashRate_Unit = $Words[$Words.IndexOf(($Words -like "*/s*" | Select-Object -Last 1))]
            }

            switch -wildcard ($HashRate_Unit) {
                "kh/s*" {$HashRate *= [Math]::Pow(1000, 1)}
                "mh/s*" {$HashRate *= [Math]::Pow(1000, 2)}
                "gh/s*" {$HashRate *= [Math]::Pow(1000, 3)}
                "th/s*" {$HashRate *= [Math]::Pow(1000, 4)}
                "ph/s*" {$HashRate *= [Math]::Pow(1000, 5)}
            }

            if (-not (Test-Path "Wrapper")) {New-Item "Wrapper" -ItemType "directory" -Force | Out-Null}
            $HashRate | ConvertTo-Json | Set-Content ".\Wrapper\$Id.txt" -Force -ErrorAction Ignore
        }

        if (($Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", "")) {Write-Host ($Line -replace "`n|`r", "")}
    }

    if (-not (Get-Process | Where-Object Id -EQ $ControllerProcessID)) {$Job | Stop-Job}
}
while ($Job.State -eq "Running")

Remove-Item ".\Wrapper\$Id.txt" -Force -ErrorAction Ignore
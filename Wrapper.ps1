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
    [String]$WorkingDirectory = ""
)

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Remove-Item ".\Wrapper_$Id.txt" -ErrorAction Ignore

$PowerShell = [PowerShell]::Create()
if ($WorkingDirectory -ne "") {$PowerShell.AddScript("Set-Location '$WorkingDirectory'") | Out-Null}
$Command = ". '$FilePath'"
if ($ArgumentList -ne "") {$Command += " $ArgumentList"}
$PowerShell.AddScript("$Command 2>&1 | Write-Verbose -Verbose") | Out-Null
$Result = $PowerShell.BeginInvoke()

Write-Host "MultiPoolMiner Wrapper Started" -BackgroundColor Yellow -ForegroundColor Black

do {
    Start-Sleep 1

    $PowerShell.Streams.Verbose.ReadAll() | ForEach-Object {
        $Line = $_

        if ($Line -like "*total speed:*" -or $Line -like "*accepted:*" -or $Line -like "*mining *:*") {
            $Words = $Line -split " "

            $matches = $null

            if ($Words[$Words.IndexOf(($Words -like "*/s" | Select-Object -Last 1))] -match "^((?:\d*\.)?\d+)(.*)$") {
                $HashRate = [Decimal]$matches[1]
                $HashRate_Unit = $matches[2]
            }
            else {
                $HashRate = [Decimal]$Words[$Words.IndexOf(($Words -like "*/s" | Select-Object -Last 1)) - 1]
                $HashRate_Unit = $Words[$Words.IndexOf(($Words -like "*/s" | Select-Object -Last 1))]
            }

            switch ($HashRate_Unit) {
                "kh/s" {$HashRate *= [Math]::Pow(1000, 1)}
                "mh/s" {$HashRate *= [Math]::Pow(1000, 2)}
                "gh/s" {$HashRate *= [Math]::Pow(1000, 3)}
                "th/s" {$HashRate *= [Math]::Pow(1000, 4)}
                "ph/s" {$HashRate *= [Math]::Pow(1000, 5)}
            }

            $HashRate | ConvertTo-Json | Set-Content ".\Wrapper_$Id.txt"
        }

        Write-Host ($Line -replace "`n|`r", "")
    }

    if ((Get-Process | Where-Object Id -EQ $ControllerProcessID) -eq $null) {$PowerShell.Stop() | Out-Null}
}
until($Result.IsCompleted)

Remove-Item ".\Wrapper_$Id.txt" -ErrorAction Ignore
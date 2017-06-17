param(
    [Parameter(Mandatory=$true)]
    [Int]$ControllerProcessID, 
    [Parameter(Mandatory=$true)]
    [String]$Id, 
    [Parameter(Mandatory=$true)]
    [String]$FilePath, 
    [Parameter(Mandatory=$false)]
    [String]$ArgumentList = "", 
    [Parameter(Mandatory=$false)]
    [String]$WorkingDirectory = ""
)

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

. .\Include.ps1

Remove-Item ".\Wrapper_$Id.txt" -ErrorAction Ignore

$PowerShell = [PowerShell]::Create()
if($WorkingDirectory -ne ""){$PowerShell.AddScript("Set-Location '$WorkingDirectory'") | Out-Null}
$Command = ". '$FilePath'"
if($ArgumentList -ne ""){$Command += " $ArgumentList"}
$PowerShell.AddScript("$Command | Write-Verbose -Verbose") | Out-Null
$Result = $PowerShell.BeginInvoke()

Write-Host "MultiPoolMiner Wrapper Started" -BackgroundColor Yellow -ForegroundColor Black

do
{
    Start-Sleep 1

    $PowerShell.Streams.Verbose.ReadAll() | ForEach-Object {
        $Line = $_

        if($Line -like "*total speed:*" -or $Line -like "*accepted:*")
        {
            $Words = $Line -split " "
            $HashRate = [Decimal]$Words[$Words.IndexOf(($Words -like "*/s" | Select-Object -Last 1))-1]

            switch($Words[$Words.IndexOf(($Words -like "*/s" | Select-Object -Last 1))])
            {
                "kh/s" {$HashRate *= [Math]::Pow(1000,1)}
                "mh/s" {$HashRate *= [Math]::Pow(1000,2)}
                "gh/s" {$HashRate *= [Math]::Pow(1000,3)}
                "th/s" {$HashRate *= [Math]::Pow(1000,4)}
                "ph/s" {$HashRate *= [Math]::Pow(1000,5)}
            }

            $HashRate | Set-Content ".\Wrapper_$Id.txt"
        }

        $Line
    }

    if((Get-Process | Where-Object Id -EQ $ControllerProcessID) -eq $null){$PowerShell.Stop() | Out-Null}
}
until($Result.IsCompleted)

Remove-Item ".\Wrapper_$Id.txt" -ErrorAction Ignore
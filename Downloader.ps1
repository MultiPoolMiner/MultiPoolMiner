using module .\Include.psm1

$DownloadList = $args

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

$Progress = 0

$DownloadList | ForEach-Object {
    $URI = $_.URI
    $Path = $_.Path
    $Searchable = $_.Searchable

    $Progress += 100 / $DownloadList.Count

    if (-not (Test-Path $Path)) {
        $ProgressPreferenceBackup = $ProgressPreference
        try {
            $ProgressPreference = $ProgressPreferenceBackup
            Write-Progress -Activity "Downloader" -Status $Path -CurrentOperation "Acquiring Online ($URI)" -PercentComplete $Progress

            $ProgressPreference = "SilentlyContinue"
            if ($URI -and (Split-Path $URI -Leaf) -eq (Split-Path $Path -Leaf)) {
                New-Item (Split-Path $Path) -ItemType "Directory" | Out-Null
                Invoke-WebRequest $URI -OutFile $Path -UseBasicParsing -ErrorAction Stop
            }
            else {
                Expand-WebRequest $URI (Split-Path $Path) -ErrorAction Stop
            }
        }
        catch {
            $ProgressPreference = $ProgressPreferenceBackup
            Write-Progress -Activity "Downloader" -Status $Path -CurrentOperation "Acquiring Offline (Computer)" -PercentComplete $Progress

            $ProgressPreference = "SilentlyContinue"
            if ($URI) {Write-Warning "Cannot download $($Path) distributed at $($URI). "}
            else {Write-Warning "Cannot download $($Path). "}

            if ($Searchable) {
                Write-Warning "Searching for $($Path). "

                $Path_Old = Get-PSDrive -PSProvider FileSystem | ForEach-Object {Get-ChildItem -Path $_.Root -Include (Split-Path $Path -Leaf) -Recurse -ErrorAction Ignore} | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
                $Path_New = $Path
            }

            if ($Path_Old) {
                if (Test-Path (Split-Path $Path_New)) {(Split-Path $Path_New) | Remove-Item -Recurse -Force}
                (Split-Path $Path_Old) | Copy-Item -Destination (Split-Path $Path_New) -Recurse -Force
            }
            else {
                if ($URI) {Write-Warning "Cannot find $($Path) distributed at $($URI). "}
                else {Write-Warning "Cannot find $($Path). "}
            }
        }
        $ProgressPreference = $ProgressPreferenceBackup
    }
}

Write-Progress -Activity "Downloader" -Completed
using module .\Include.psm1

$DownloadList = $args

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

$Progress = 0

$DownloadList | ForEach-Object {
    $URI = $_.URI
    $Path = $_.Path
    $Searchable = $_.Searchable

    $Progress += 100 / $DownloadList.Count

    if (-not (Test-Path $Path -PathType Leaf)) {
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
                Expand-WebRequest $URI $Path -ErrorAction Stop
            }
            Write-Log -Level Verbose "Installed miner binary ($($Path)). "
        }
        catch {
            $ProgressPreference = $ProgressPreferenceBackup
            Write-Progress -Activity "Downloader" -Status $Path -CurrentOperation "Acquiring Offline (Computer)" -PercentComplete $Progress

            $ProgressPreference = "SilentlyContinue"
            if ($URI) {Write-Log -Level Warn "Cannot download $($Path) distributed at $($URI). "}
            else {Write-Log -Level Warn "Cannot download $($Path). "}

            if ($Searchable) {
                Write-Log -Level Warn "Searching for $($Path). "

                $Path_Old = Get-PSDrive -PSProvider FileSystem | ForEach-Object {Get-ChildItem -Path $_.Root -Include (Split-Path $Path -Leaf) -Recurse -ErrorAction Ignore} | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
                $Path_New = $Path
            }

            if ($Path_Old) {
                if (Test-Path (Split-Path $Path_New) -PathType Container) {(Split-Path $Path_New) | Remove-Item -Recurse -Force}
                (Split-Path $Path_Old) | Copy-Item -Destination (Split-Path $Path_New) -Recurse -Force
                Write-Log -Level Verbose "Installed $($Path). "
            }
            else {
                if ($URI) {Write-Log -Level Warn "Cannot find $($Path) distributed at $($URI). "}
                else {Write-Log -Level Warn "Cannot find $($Path). "}
            }
        }
        $ProgressPreference = $ProgressPreferenceBackup
    }
}

Write-Progress -Activity "Downloader" -Status "Completed" -Completed

return

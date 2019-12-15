using module ..\..\Include.psm1

param(
    [PSCustomObject]$Parameters
)

if ($Parameters) { 
    $Parameters | ConvertTo-Json -Depth 5 | Set-Content -Path ".\Debug\ManageConfig.json" -Force -ErrorAction SilentlyContinue
}
else { 
    Set-Location (Split-Path (Split-Path (Split-Path $MyInvocation.MyCommand.Path)))
    $API = Get-Content ".\Debug\Api.json" | ConvertFrom-Json
    $Parameters = Get-Content  -Path ".\Debug\ManageConfig.json" -ErrorAction SilentlyContinue | ConvertFrom-Json    
}

$Config = Get-Content $API.Config.ConfigFile | ConvertFrom-Json
$Data = @($Parameters.Data | ConvertFrom-Json -ErrorAction SilentlyContinue)

$Text = "`nConfig Parameter '$($Parameters.Key)' changed:"
$Text += "`nOld value$(if ($Config.$($Parameters.Key).Count -ne 1) { "s" }):`n'$($Config.$($Parameters.Key) -join '; ')'"

Switch ($Parameters.Action) { 
    "Add" { 
        if ($Data.Count) { 
            $Data | ForEach-Object { 
                $DataItem = $_ | Select-Object            
                Switch ($API.Config.$($Parameters.Key).GetType().BaseType) { 
                    "Array" { 
                        $Config.($Parameters.Key) = @(Compare-Object @($Config.($Parameters.Key) | Where-Object {$_ -notlike "`$*" } | Select-Object) @($DataItem | Select-Object) -IncludeEqual | Select-Object InputObject).InputObject | Sort-Object -Unique
                        if ($Parameters.DataSet -eq "AllDevices") { 
                            #Update API data
                            $API.($Parameters.DataSet) | Where-Object { $_.Name -in $DataItem } | ForEach-Object { $_.Status = "Disabled"}
                        }
                    }
                    default { 
                        $Config.$($Parameters.Key) = $_
                    }
                }
            }
        }
    }
    "Get" { 
        #To be implemented
    }
    "Remove" { 
        if ($Data.Count) { 
            $Data | ForEach-Object { 
                $DataItem = $_ | Select-Object
                Switch ($API.Config.$($Parameters.Key).GetType().BaseType) { 
                    "Array" { 
                        $Config.($Parameters.Key) = @(Compare-Object @($Config.($Parameters.Key) | Where-Object {$_ -notlike "`$*" } | Select-Object) @($DataItem | Select-Object) | Where-Object SideIndicator -EQ "<=" | Select-Object InputObject).InputObject | Sort-Object -Unique
                        if (-not $Config.($Parameters.Key).Count) { 
                            $Config.($Parameters.Key) = "`$$([String]$Parameters.Key)"
                        }
                        if ($Parameters.DataSet -eq "AllDevices") { 
                            #Update API data
                            $API.($Parameters.DataSet) | Where-Object { $_.Name -in $DataItem } | ForEach-Object { $_.Status = "Enabled"}
                        }
                    }
                    default { 
                        $Config.$($Parameters.Key) = $null
                    }
                }
            }
        }
    }
    "Set" { 
        #To be implemented
    }
}

if ($Parameters.Action -match "Add|Remove|Set") { 
    $Config | ConvertTo-Json -Depth 10 | Set-Content $API.Config.ConfigFile -Force
    $Config = Get-Content $API.Config.ConfigFile | ConvertFrom-Json
    $Text += "`n`nNew value$(if ($Config.$($Parameters.Key).Count -ne 1) { "s" }): `n'$($Config.$($Parameters.Key) -join '; ')'"
    $Text += "`n`nConfig file ($($API.Config.ConfigFile)) saved. "
    if ($Parameters.DataSet -eq "AllDevices" -and $Config.($Parameters.Key) -notlike "`$*") { $Text += "`n`nNote: The saved setting overrides the corresponding parameter `n-$($Parameters.Key)`nthat might be defined in the start batch file. " }
}

Write-Output "<pre>"
$Text | Write-Output
Write-Output "</pre>"

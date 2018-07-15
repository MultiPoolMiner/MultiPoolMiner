Function Start-APIServer {
    # Create a global synchronized hashtable that all threads can access to pass data between the main script and API
    $Global:API = [hashtable]::Synchronized(@{})
  
    # Setup flags for controlling script execution
    $API.Stop = $false
    $API.Pause = $false

    # Setup runspace to launch the API webserver in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("API", $API)
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd)) | Out-Null

    $apiserver = [PowerShell]::Create().AddScript({

        # Set the starting directory
        Set-Location (Split-Path $MyInvocation.MyCommand.Path)
        $BasePath = "$PWD\web"

        # List of possible mime types for files
        $MIMETypes = @{
            ".js" = "application/x-javascript"
            ".html" = "text/html"
            ".htm" = "text/html"
            ".json" = "application/json"
            ".css" = "text/css"
            ".txt" = "text/plain"
            ".ico" = "image/x-icon"
            ".ps1" = "text/html" # ps1 files get executed, assume their response is html
        }

        # Setup the listener
        $Server = New-Object System.Net.HttpListener
        # Listening on anything other than localhost requires admin privileges
        $Server.Prefixes.Add("http://localhost:3999/")
        $Server.Start()

        While ($Server.IsListening) {
            $Context = $Server.GetContext()
            $Request = $Context.Request
            $URL = $Request.Url.OriginalString

            # Determine the requested resource and parse query strings
            $Path = $Request.Url.LocalPath

            # Parse any parameters in the URL - $Request.Url.Query looks like "+ ?a=b&c=d&message=Hello%20world"
            $Parameters = [PSCustomObject]@{}
            $Request.Url.Query -Replace "\?", "" -Split '&' | Foreach-Object {
                $key, $value = $_ -Split '='
                # Decode any url escaped characters in the key and value
                $key = [URI]::UnescapeDataString($key)
                $value = [URI]::UnescapeDataString($value)
                if ($key -and $value) {
                    $Parameters | Add-Member $key $value
                }
            }

            # Create a new response and the defaults for associated settings
            $Response = $Context.Response
            $ContentType = "application/json"
            $StatusCode = 200
            $Data = ""

            # Set the proper content type, status code and data for each resource
            Switch($Path) {
                "/version" {
                    $Data = $API.Version | ConvertTo-Json
                    break
                }
                "/activeminers" {
                    $Data = ConvertTo-Json @($API.ActiveMiners | Select-Object)
                    break
                }
                "/runningminers" {
                    $Data = ConvertTo-Json @($API.RunningMiners | Select-Object)
                    Break
                }
                "/failedminers" {
                    $Data = ConvertTo-Json @($API.FailedMiners | Select-Object)
                    Break
                }
                "/minersneedingbenchmark" {
                    $Data = ConvertTo-Json @($API.MinersNeedingBenchmark | Select-Object)
                    Break
                }
                "/pools" {
                    $Data = ConvertTo-Json @($API.Pools | Select-Object)
                    Break
                }
                "/newpools" {
                    $Data = ConvertTo-Json @($API.NewPools | Select-Object)
                    Break
                }
                "/allpools" {
                    $Data = ConvertTo-Json @($API.AllPools | Select-Object)
                    Break
                }
                "/algorithms" {
                    $Data = ConvertTo-Json @($API.AllPools.Algorithm | Sort-Object -Unique)
                    Break
                }
                "/miners" {
                    $Data = ConvertTo-Json @($API.Miners | Select-Object)
                    Break
                }
                "/fastestminers" {
                    $Data = ConvertTo-Json @($API.FastestMiners | Select-Object)
                    Break
                }
                "/config" {
                    $Data = $API.Config | ConvertTo-Json
                    Break
                }
                "/debug" {
                    $Data = $API | ConvertTo-Json
                    Break
                }
                "/devices" {
                    $Data = ConvertTo-Json @($API.Devices | Select-Object)
                    Break
                }
                "/stats" {
                    $Data = ConvertTo-Json @($API.Stats | Select-Object)
                    Break
                }
                "/watchdogtimers" {
                    $Data = ConvertTo-Json @($API.WatchdogTimers | Select-Object)
                    Break
                }
                "/balances" {
                    $Data = ConvertTo-Json @($API.Balances | Select-Object)
                    Break
                }
                "/currentprofit" {
                    $Data = ($API.RunningMiners | Measure-Object -Sum -Property Profit).Sum | ConvertTo-Json
                    Break
                }
                "/stop" {
                    $API.Stop = $true
                    $Data = "Stopping"
                    break
                }
                default {
                    # Set index page
                    if ($Path -eq "/") {
                        $Path = "/index.html"
                    }

                    # Check if there is a file with the requested path
                    $Filename = $BasePath + $Path
                    if (Test-Path $Filename -PathType Leaf) {
                        # If the file is a powershell script, execute it and return the output. A $Parameters parameter is sent built from the query string
                        # Otherwise, just return the contents of the file
                        $File = Get-ChildItem $Filename

                        If ($File.Extension -eq ".ps1") {
                            $Data = & $File.FullName -Parameters $Parameters
                        } else {
                            $Data = Get-Content $Filename -Raw

                            # Process server side includes for html files
                            # Includes are in the traditional '<!-- #include file="/path/filename.html" -->' format used by many web servers
                            if($File.Extension -eq ".html") {
                                $IncludeRegex = [regex]'<!-- *#include *file="(.*)" *-->'
                                $IncludeRegex.Matches($Data) | Foreach-Object {
                                    $IncludeFile = $BasePath +'/' + $_.Groups[1].Value
                                    If (Test-Path $IncludeFile -PathType Leaf) {
                                        $IncludeData = Get-Content $IncludeFile -Raw
                                        $Data = $Data -Replace $_.Value, $IncludeData
                                    }
                                }
                            }
                        }

                        # Set content type based on file extension
                        If ($MIMETypes.ContainsKey($File.Extension)) {
                            $ContentType = $MIMETypes[$File.Extension]
                        } else {
                            # If it's an unrecognized file type, prompt for download
                            $ContentType = "application/octet-stream"
                        }
                    } else {
                        $StatusCode = 404
                        $ContentType = "text/html"
                        $Data = "URI '$Path' is not a valid resource."
                    }
                }
            }

            # If $Data is null, the API will just return whatever data was in the previous request.  Instead, show an error
            # This happens if the script just started and hasn't filled all the properties in yet.
            If($Data -eq $Null) { 
                $Data = @{'Error' = "API data not available"} | ConvertTo-Json
            }

            # Send the response
            $Response.Headers.Add("Content-Type", $ContentType)
            $Response.StatusCode = $StatusCode
            $ResponseBuffer = [System.Text.Encoding]::UTF8.GetBytes($Data)
            $Response.ContentLength64 = $ResponseBuffer.Length
            $Response.OutputStream.Write($ResponseBuffer,0,$ResponseBuffer.Length)
            $Response.Close()

        }
        # Only gets here if something is wrong and the server couldn't start or stops listening
        $Server.Stop()
        $Server.Close()
    }) #end of $apiserver

    $apiserver.Runspace = $newRunspace
    $apihandle = $apiserver.BeginInvoke()
}

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
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd))

    $apiserver = [PowerShell]::Create().AddScript({

        # Setup the listener
        $Server = New-Object System.Net.HttpListener
        # Listening on anything other than localhost requires admin priviledges
        $Server.Prefixes.Add("http://localhost:3999/")
        $Server.Start()

        While ($Server.IsListening) {
            $Context = $Server.GetContext()
            $Request = $Context.Request
            $URL = $Request.Url.OriginalString

            # Determine the requested resource - remove any query strings and trailing slashes
            $RequestedResource = ($Request.RawUrl -Split '\?')[0].TrimEnd('/')

            # Create a new response and the defaults for associated settings
            $Response = $Context.Response
            $ContentType = "application/json"
            $StatusCode = 200
            $Data = ""

            # Set the proper content type, status code and data for each resource
            Switch($RequestedResource) {
                "" {
                    $ContentType = "text/html"
                    $Data = Get-Content('APIDocs.html')
                    break
                }
                "/version" {
                    $Data = $API.Version | ConvertTo-Json
                    break
                }
                "/activeminers" {
                    $Data = $API.ActiveMiners | ConvertTo-Json
                    break
                }
                "/runningminers" {
                    $Data = $API.RunningMiners | ConvertTo-Json
                    Break
                }
                "/failedminers" {
                    $Data = $API.FailedMiners | ConvertTo-Json
                    Break
                }
                "/pools" {
                    $Data = $API.Pools | ConvertTo-Json
                    Break
                }
                "/newpools" {
                    $Data = $API.NewPools | ConvertTo-Json
                    Break
                }
                "/allpools" {
                    $Data = $API.AllPools | ConvertTo-Json
                    Break
                }
                "/algorithms" {
                    $Data = ($API.AllPools.Algorithm | Sort-Object -Unique) | ConvertTo-Json
                    Break
                }
                "/miners" {
                    $Data = $API.Miners | ConvertTo-Json
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
                    $Data = $API.Devices | ConvertTo-Json
                    Break
                }
                "/stats" {
                    $Data = $API.Stats | ConvertTo-Json
                    Break
                }
                "/watchdogtimers" {
                    $Data = $API.WatchdogTimers | ConvertTo-Json
                    Break
                }
                "/stop" {
                    $API.Stop = $true
                    $Data = "Stopping"
                    break
                }
                default {
                    $StatusCode = 404
                    $ContentType = "text/html"
                    $Data = "URI '$RequestedResource' is not a valid resource."
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
    }) #end of $apiserver

    $apiserver.Runspace = $newRunspace
    $apihandle = $apiserver.BeginInvoke()
}
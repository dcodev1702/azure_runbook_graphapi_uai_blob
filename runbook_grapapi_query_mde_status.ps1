Write-Output "Azure Runbook using User Assigned Identity & Graph API!"

#Import-Module PowerShellGet

# The latest version of Microsoft.Graph.Authentication DOES NOT WORK for Runbooks.
# You have to pin the module to version 2.25.0 and install it, THEN IT WORKS (Connect-MgGraph -AccessToken)
# SOLUTION: https://learn.microsoft.com/en-us/answers/questions/2237145/invalid-jwt-access-token
Install-Module -Name Microsoft.Graph.Authentication -RequiredVersion 2.25.0 -Scope CurrentUser -Force

Import-Module Microsoft.Graph.Authentication

try {
    # User Assigned Managed Identity:
    Connect-AzAccount -Identity -AccountId '394fffc6-27d9-44f6-9f1a-98db7e13f33a' -Environment AzureCloud -ErrorAction Stop

    Get-AzContext | fl *

    # Get the token using a managed identity and use that token (secure string) to connect to the Graph API
    $AccessToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"

    # Convert the JWP (token) to a SecureString
    $SecureAccessToken = $AccessToken.Token | ConvertTo-SecureString -AsPlainText -Force

    # Using the login / token from the user managed identity and the assigned scopes (done via CLI)
    Connect-MgGraph -AccessToken $SecureAccessToken -NoWelcome -ErrorAction Stop
    
    Get-MgContext | fl *

    # Import the module(s) you plan on using with the GraphAPI
    Import-Module Microsoft.Graph.Security
 
} catch {
    Write-Error $_.Exception.Message -ErrorAction Stop
}

#[string]$KqlQuery = "DeviceInfo | where TimeGenerated > ago(1d) | take 3"
[string]$KqlQuery = "let AVDetails = DeviceTvmInfoGathering | extend avdata = parsejson(AdditionalFields) | extend AVMode = iif(tostring(avdata.AvMode)=='0','Active/Normal',iif(tostring(avdata.AvMode)=='1','Passive',iif(tostring(avdata.AvMode)=='3','SxS Passive',iif(tostring(avdata.AvMode)=='4','EDR Blocked','Unknown')))) | project DeviceId, DeviceName, AVMode; let DeviceDetails = DeviceInfo | extend ig = ingestion_time() | extend ScopeTag = tostring(parse_json(AdditionalFields).scopeTag) | summarize arg_max(Timestamp,*) by DeviceId | where MachineGroup=='EUROPE' | project DeviceId, MachineGroup, OSPlatform, ScopeTag, LastSeen=Timestamp; AVDetails | join kind=inner(DeviceDetails) on DeviceId | project DeviceName, MachineGroup, AVMode, OSPlatform, LastSeen"

# Define Graph API details
# Note: Invoke-MgGraphRequest can use a full URI or a relative path if connected.
# Using the full URI here as requested.
$GraphEndpointPath = "https://graph.microsoft.com/v1.0/security/runHuntingQuery"
$OutputFile        = "devices.txt"
$apiResponse       = $null

Write-Output "Starting script to call Graph Security API using assumed user authentication."
Write-Output "KQL Query: $($KqlQuery)"
Write-Output "Output file: $($OutputFile)"
Write-Output "Assuming existing Graph connection with SecurityEvents.ReadWrite.All scope."

# region Prepare and Execute Graph API Call
Write-Output "Preparing Graph API call to $($GraphEndpointPath)."

# Define the request body for the hunting query
$body = @{
    "Query" = $KqlQuery
} | ConvertTo-Json -Depth 25

Write-Output "Request Body: $($body)"

try {
    Write-Output "Executing POST request to Graph API endpoint $($GraphEndpointPath)..."

    # Invoke the Graph API endpoint using Invoke-MgGraphRequest
    # This cmdlet uses the authenticated context from the Connect-MgGraph session
    # that is assumed to be established prior to running this script.
    # It can accept a full URI or a relative path.
    $apiResponse = Invoke-MgGraphRequest -Method POST -Uri $GraphEndpointPath -Body $body -ErrorAction Stop

    Write-Verbose "Graph API call successful."
}
catch {
    Write-Error "Failed to call Graph Security API."
    Write-Error "Error details: $($_.Exception.Message)"

    # Invoke-MgGraphRequest errors might not have a direct Response property like Invoke-RestMethod
    # Additional error details might be in $_.Exception.InnerException or $_.ErrorDetails
    if ($_.Exception.InnerException) {
        Write-Error "Inner Exception: $($_.Exception.InnerException.Message)"
    }
    if ($_.ErrorDetails) {
        Write-Error "Error Details: $($_.ErrorDetails)"
    }

    # Add a specific message if authentication seems to be the issue
    if ($_.Exception.Message -like "*authentication*" -or $_.Exception.Message -like "*token*") {
        Write-Error "Authentication may have failed. Ensure Connect-MgGraph was run successfully with the required scope before this script."
    }

    throw "API call failed."
}
# endregion

# Convert the data to CSV format
$csvData = $apiResponse.results | ConvertTo-Csv -NoTypeInformation

$csvData | Set-Content -Path $OutputFile -Encoding UTF8 -Force

# ————————————————————————————————
# Upload devices.txt to blob storage
# ————————————————————————————————
Write-Output "Uploading $OutputFile to Blob storage 'audsmigration/mdedevices/devices.txt'"

# 2. Create a storage context for 'audsmigration' using that login
$storageContext = New-AzStorageContext -StorageAccountName 'audsmigration' -UseConnectedAccount

# 3. Upload the local file as a blob named 'devices.txt'
Set-AzStorageBlobContent `
    -Context      $storageContext `
    -Container    'mdedevices' `
    -File         "C:\app\$OutputFile" `
    -Blob         'devices.txt' `
    -Force         # overwrite if it already exists

Write-Output "Upload complete."

Disconnect-MgGraph
Disconnect-AzAccount

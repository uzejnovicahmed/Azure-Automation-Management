

function Get-Token{

param (
    [Parameter()]
    [ValidateSet("Hybrid","Cloud")]
    [string]$Environment = "Hybrid",   # Hybrid, Cloud

    [Parameter()]
    [ValidateSet("AzureArc","AzureVM")]
    [string]$Resource = "AzureArc",    # AzureArc, AzureVM

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceURL
)

$global:TokenResponse = $null



$ResourceURL=$ResourceURL + "&api-version=2020-06-01"


#Here we check if the global variable is set. If it is not, we authenticate and get the token from the endpoint
    if ($null -eq $global:TokenResponse) {
        #write-au2matorLog -Type INFO -Text "Getting KeyVault Token"
        if ($Environment -eq "Hybrid") {
            if ($Resource -eq "AzureArc") {
               
               
                $endpoint = "http://localhost:40342/metadata/identity/oauth2/token?resource=$ResourceURL" #Azure Arc
               
                try { Invoke-WebRequest -Method GET -Uri $endpoint -Headers @{Metadata = 'True' } -UseBasicParsing } 
                catch {                 
                    if ($psversiontable.PSVersion -lt [version]'6.0') {
                        $wwwAuthHeader = $_.Exception.Response.Headers["WWW-Authenticate"];
                    }
                    else
                    { $_.Exception.Response.Headers | where { $_.key -eq "WWW-Authenticate" } | ForEach-Object { $wwwAuthHeader = $_.Value } }

                }

                if ($wwwAuthHeader -match "Basic realm=.+") {         
                    $secretFile = ($wwwAuthHeader -split "Basic realm=")[1]
                } 
                $secret = cat -Raw $secretFile 
                $global:TokenResponse = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -Method GET -Uri $endpoint -Headers  @{Metadata = 'True'; Authorization = "Basic $secret" } -UseBasicParsing).RawContentStream.ToArray()) | ConvertFrom-Json
            }
            elseif ($Resource -eq "AzureVM") {
                $endpoint = "http://169.254.169.254/metadata/identity/oauth2/token?resource=$ResourceURL" #AzureVM
                $global:TokenResponse = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -Method GET -Uri $endpoint -Headers @{Metadata = 'True' } -UseBasicParsing).RawContentStream.ToArray()) | ConvertFrom-Json
            }
        }
        else {
            $global:TokenResponse = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True' }).RawContentStream.ToArray()) | ConvertFrom-Json
        }
    }
    else {
        #Token is already set, do nothing        
    }

 return $TokenResponse.access_token

}



$token= Get-Token -ResourceURL "api://AzureADTokenExchange" #Generate the token from the App Registration

# Inputs
$TenantId = "<your Tenant ID>"  
$AppClientId     = "<Your Azure Application Client ID>"    
$scope           = "https://graph.microsoft.com/.default"  

$tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

$body = @{
    client_id             = $AppClientId
    scope                 = $scope
    grant_type            = "client_credentials"
    client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
    client_assertion      = $Token
}

$appTokenResponse = Invoke-RestMethod -Method POST -Uri $tokenEndpoint `
  -ContentType "application/x-www-form-urlencoded" -Body $body

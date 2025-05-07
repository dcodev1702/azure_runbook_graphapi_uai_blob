# Create the user managed identity
$RGName   = 'SecOps'
$miName   = 'uai-audsmigration'
$location = 'eastus2'

$mi = New-AzUserAssignedIdentity -ResourceGroupName $RGName -Name $miName -Location $location -ErrorAction Stop

Write-Host "Successfully created User-Assigned Managed Identity:"
$mi | Format-List *

# You can access properties like the PrincipalId and ClientId
Write-Host "`nUser-Assigned Identity -> Principal ID: $($mi.PrincipalId)"

# Assign the required roles to the User Managed Identity
New-AzRoleAssignment -ObjectId $mi.PrincipalId -ResourceGroupName $RGName -RoleDefinitionName Reader
New-AzRoleAssignment -ObjectId $mi.PrincipalId -ResourceGroupName $RGName -RoleDefinitionName 'Automation Job Operator'
New-AzRoleAssignment -ObjectId $mi.PrincipalId -ResourceGroupName $RGName -RoleDefinitionName 'Automation Runbook Operator'

# Get the App Id for the Microsoft Graph API
$graphSPN = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

  # Assign the following Graph API Scopes to the User Assigned (Managed) Identity
  $mgScopes = @("User.Read.All", "SecurityEvents.Read.All", "ThreatHunting.Read.All")
  $mgScopes | ForEach-Object {
    $appRole = $graphSPN.AppRoles | Where-Object Value -eq $_ | Where-Object AllowedMemberTypes -contains "Application"
  
    $bodyParam = @{
      PrincipalId = $mii.PrincipalId
      ResourceId  = $graphSPN.Id
      AppRoleId   = $appRole.Id
    }

    # Assign the Graph API Scope to the user managed identity
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mii.PrincipalId -BodyParameter $bodyParam
  }

Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mi.PrincipalId | Format-List PrincipalDisplayName, ResourceDisplayName, AppRoleId


# !!!!!    ATTENTION    !!!!!
# If you ever need to remove Graph API role assignments
<#
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mii.PrincipalId | select Id | ForEach-Object { 
  Remove-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mii.PrincipalId -AppRoleAssignmentId $_.Id -ErrorAction Stop -Confirm:$false
}
#>

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

$graphSPN = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

  $mgScopes = @("User.Read.All", "SecurityEvents.Read.All", "ThreatHunting.Read.All")
  $mgScopes | ForEach-Object {
    $appRole = $graphSPN.AppRoles | Where-Object Value -eq $_ | Where-Object AllowedMemberTypes -contains "Application"
  
    $bodyParam = @{
      PrincipalId = $mi.PrincipalId
      ResourceId  = $graphSPN.Id
      AppRoleId   = $appRole.Id
    }

    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mi.PrincipalId -BodyParameter $bodyParam
  }


Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mi.PrincipalId | Format-List PrincipalDisplayName, ResourceDisplayName, AppRoleId

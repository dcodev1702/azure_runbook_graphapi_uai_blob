# Create the user managed identity
$RGName   = 'SecOps'
$miName   = 'uai-audsmigration'
$location = 'eastus2'
$saName   = 'audsmigration'
$ctrName  = 'mdedevices'

$mi = New-AzUserAssignedIdentity -ResourceGroupName $RGName -Name $miName -Location $location -ErrorAction Stop

Write-Host "Successfully created User-Assigned Managed Identity:"
$mi | Format-List *

# You can access properties like the PrincipalId and ClientId
Write-Host "`nUser-Assigned Identity -> Principal ID: $($mi.PrincipalId)"

# Create an ALDSv2 Storage Account
$storageAccount = New-AzStorageAccount -ResourceGroupName $RGName `
  -Name $saName `
  -Location $location `
  -SkuName Standard_LRS `
  -Kind StorageV2 `
  -EnableHierarchicalNamespace $true `
  -AllowSharedKeyAccess $false `
  -EnableHttpsTrafficOnly $true `
  -MinimumTlsVersion TLS1_2 `
  -IdentityType UserAssigned `
  -UserAssignedIdentityId $mi.Id

# Disable Soft Delete (File Service)
Update-AzStorageFileServiceProperty -ResourceGroupName $RGName -StorageAccountName $saName -EnableShareDeleteRetentionPolicy $false

# Get context for current storage account
$ctx = New-AzStorageContext -StorageAccountName $saName -UseConnectedAccount

# Use the context of the current storage account to create the desired blob container
New-AzStorageContainer -Name $ctrName -Context $ctx

# Assign the user managed identity the Storage Blob Data Contributor role scoped to the container.
New-AzRoleAssignment -ObjectId $mi.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $storageAccount.Id + "/blobServices/default/containers/${ctrName}"

# Assign the required roles to the User Managed Identity
New-AzRoleAssignment -ObjectId $mi.PrincipalId -ResourceGroupName $RGName -RoleDefinitionName 'Reader'
New-AzRoleAssignment -ObjectId $mi.PrincipalId -ResourceGroupName $RGName -RoleDefinitionName 'Automation Job Operator'
New-AzRoleAssignment -ObjectId $mi.PrincipalId -ResourceGroupName $RGName -RoleDefinitionName 'Automation Runbook Operator'

# Get the App Id for the Microsoft Graph API
$graphSPN = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

  # Assign the following Graph API Scopes to the User Assigned (Managed) Identity
  $mgScopes = @("User.Read.All", "SecurityEvents.Read.All", "ThreatHunting.Read.All")
  $mgScopes | ForEach-Object {
    $appRole = $graphSPN.AppRoles | Where-Object Value -eq $_ | Where-Object AllowedMemberTypes -contains "Application"
  
    $bodyParam = @{
      PrincipalId = $mi.PrincipalId
      ResourceId  = $graphSPN.Id
      AppRoleId   = $appRole.Id
    }

    # Assign the Graph API Scope to the user managed identity
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mi.PrincipalId -BodyParameter $bodyParam
  }

Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mi.PrincipalId | Format-List PrincipalDisplayName, ResourceDisplayName, AppRoleId


# !!!!!    ATTENTION    !!!!!
# If you ever need to remove Graph API role assignments
<#
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mi.PrincipalId | select Id | ForEach-Object { 
  Remove-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mi.PrincipalId -AppRoleAssignmentId $_.Id -ErrorAction Stop -Confirm:$false
}
#>

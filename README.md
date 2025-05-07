# azure_runbook_graphapi_uai_blob

1. Create user managed identity
2. Assign Azure Roles to the identity
   ![6B053984-4558-48AA-A045-D26817FE177E](https://github.com/user-attachments/assets/a00cdccc-930a-4a63-80eb-c7698ba7c042)

4. Assign Microsoft Graph Scopes to the identity ("SecurityEvents.ReadWrite.All", "ThreatHunting.Read.All")
   ![D8C83857-11AC-4B9D-B826-683C9AD1E05F](https://github.com/user-attachments/assets/40ced0ab-aca0-4856-8653-bb4c805f70f8)

6. Create an ADLSv2 storage account & blob container </br>
   * Associate Azure Role: Storage Blob Data Contributor to the user managed identity
7. Create an Automation Account / Runbook with PowerShell 7.2 >=  </br>
   * Associate Azure Role: Automation Job Operator to the user managed identity
   * Associate Azure Role: Automation Runbook Operator to the user managed identity
9. Create a custom PowerShell Runtime Environment and install the Microsoft.Graph.Security module </br>
   ![BFB9D653-2680-4F1D-934F-CBDF2B6FDE78](https://github.com/user-attachments/assets/f03bc4e6-9f31-4e31-9a22-de0a619ef1ec)

10. Right now the Microsoft.Graph.Authentication PowerShell module has to be installed in the Runbook bec only version 2.25.0 works w/ Connect-MgGraph
11. Make necessary Graph API calls. Ensure you have the correct and corresponding modules installed </br>
    https://learn.microsoft.com/en-us/graph/api/security-security-runhuntingquery?view=graph-rest-1.0&tabs=http

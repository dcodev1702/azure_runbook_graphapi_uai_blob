# Azure Runbook | Graph API | User Managed Identity | ADLSv2 (blob)

1. Create user managed identity
   * Refer to and run: user_managed_identity_setup.ps1
3. Assign Azure Roles to the identity
   ![6B053984-4558-48AA-A045-D26817FE177E](https://github.com/user-attachments/assets/a00cdccc-930a-4a63-80eb-c7698ba7c042)

4. Assign Microsoft Graph Scopes to the identity ("SecurityEvents.Read.All", "ThreatHunting.Read.All")
   ![D8C83857-11AC-4B9D-B826-683C9AD1E05F](https://github.com/user-attachments/assets/40ced0ab-aca0-4856-8653-bb4c805f70f8)

6. Create an ADLSv2 storage account & blob container </br>
   * Associate Azure Role: Storage Blob Data Contributor to the user managed identity
7. Create an Automation Account / Runbook with PowerShell 7.2 >=  </br>
   * Associate Azure Role: Automation Job Operator to the user managed identity
   * Associate Azure Role: Automation Runbook Operator to the user managed identity
     
9. Create a custom PowerShell Runtime Environment and install the Microsoft.Graph.Security module </br>
   ![BFB9D653-2680-4F1D-934F-CBDF2B6FDE78](https://github.com/user-attachments/assets/f03bc4e6-9f31-4e31-9a22-de0a619ef1ec)

10. As of [7 May 2025] version [2.25.0](https://learn.microsoft.com/en-us/answers/questions/2237145/invalid-jwt-access-token) of the Microsoft.Graph.Authentication has to be installed in the Runbook IOT successfully use Connect-MgGraph. </br>
    * Prevents ERROR: 'Invalid JWT Token' when trying to authenticate to the Graph API.
    ```powershell
    Install-Module -Name Microsoft.Graph.Authentication -RequiredVersion 2.25.0 -Scope CurrentUser -Force
    ```
    ```powershell
    Connect-AzAccount -Identity -AccountId '394ffxxx-xxxx-44f6-xxxx-98db7e1xxxxx' -Environment AzureCloud -ErrorAction Stop
    $AccessToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"

    # Convert the JWP (token) to a SecureString and Connect to the Graph API w/ associated scope via user managed identity
    Connect-MgGraph -AccessToken ($AccessToken.Token | ConvertTo-SecureString -AsPlainText -Force) -NoWelcome -ErrorAction Stop
    ```
11. Make necessary Graph API calls via PowerShell and ensure you have the correct / corresponding modules installed in your Runtime Environment </br>
    https://learn.microsoft.com/en-us/graph/api/security-security-runhuntingquery?view=graph-rest-1.0&tabs=http

12. Successful Runbook execution
    * Write a KQL hunting query and POST via Graph Security API call.
    ![A1F1B76A-D419-4C05-BA0B-79315B39FECD_1_201_a](https://github.com/user-attachments/assets/74738b4d-552b-45b3-a72b-a398b3fc5f71)

    * Azure Runbook results (JSON) after successful execution.
    ![image](https://github.com/user-attachments/assets/180ea771-baea-4afc-8b8d-aba7a6c4f6dc)

    * Convert the results from JSON to CSV and send the data as a file (devices.txt) to ADLSv2 Blob storage container.
    ![AD32FFB7-5641-49A7-9DB6-A3EFEF363CBF](https://github.com/user-attachments/assets/7d13d4c0-f275-4fa3-b754-04b08062df1d)


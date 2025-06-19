# 🔄 Retrieve and Export Azure Automation Jobs with All Parameters

This PowerShell script retrieves Azure Automation jobs from the last **7 days** for a specific runbook, enriches each job with missing details, normalizes all parameters so every column is present, and finally exports everything to a CSV file for easy analysis.

---

## Prerequisites

Make sure you:

1. Have the **Az.Automation** module installed.
2. Are signed in to Azure and have set the correct subscription context.

```powershell
# Sign in and select your subscription
Connect-AzAccount
Set-AzContext -Subscription "YourSubscriptionName"

# Import (or install) the Az.Automation module
# Install-Module Az.Automation -Force   # Uncomment if not yet installed
Import-Module Az.Automation
```

---

## Define Variables

Replace the placeholder values with your Automation Account, Resource Group, and Runbook names.

```powershell
$AutomationAccountName = 'AutomationAccountName'
$ResourceGroupName     = 'ResourceGroupName'
$RunbookName           = 'Your Runbook name'

$AutoAccount = @{
    AutomationAccountName = $AutomationAccountName
    ResourceGroupName     = $ResourceGroupName
}
```

---

## Get Jobs from the Last 7 Days

```powershell
# Calculate the time window
$StartTime = (Get-Date).AddDays(-7)

# Retrieve job metadata for the specified runbook
$Jobs = Get-AzAutomationJob @AutoAccount -RunbookName $RunbookName -StartTime $StartTime
```

---

## Enrich Job Objects with Missing Details

Some properties—such as **JobParameters**, **StatusDetails**, and **StartedBy**—are not included in the initial response.  
Loop through each job to pull the full details.

```powershell
$count      = 0
$jobsCount  = $Jobs.Count

foreach ($Job in $Jobs) {
    $count++
    Write-Output "$($count) of $($jobsCount) processed → JOBID: $($Job.JobId)"

    # Re‑query the job to get the full payload
    $automationJob = Get-AzAutomationJob @AutoAccount -Id $Job.JobId

    # Merge the additional fields back into the original object
    $Job.JobParameters = $automationJob.JobParameters
    $Job.StatusDetails = $automationJob.StatusDetails
    $Job.StartedBy     = $automationJob.StartedBy
    $Job.Exception     = $automationJob.Exception
}
```

---

## Collect All Parameter Names

Gather every unique parameter key so that the final CSV has a column for each one.

```powershell
$allParameterNames = @()

foreach ($job in $Jobs) {
    if ($job.JobParameters) {
        $allParameterNames += $job.JobParameters.Keys
    }
}

$allParameterNames = $allParameterNames | Sort-Object -Unique
```

---

## Build a Consistent Output Object

Create a new `[pscustomobject]` for each job, ensuring **every** parameter appears as a column (even if the value is `$null`).

```powershell
$JobList = @()

foreach ($job in $Jobs) {
    $entry = [ordered]@{
        JobId         = $job.JobId
        CreationTime  = $job.CreationTime
        Status        = $job.Status
        StatusDetails = $job.StatusDetails
        StartTime     = $job.StartTime
        EndTime       = $job.EndTime
        Exception     = $job.Exception
        RunbookName   = $job.RunbookName
        HybridWorker  = $job.HybridWorker
        StartedBy     = $job.StartedBy
    }

    foreach ($param in $allParameterNames) {
        $entry[$param] = if ($job.JobParameters.ContainsKey($param)) {
            $job.JobParameters[$param]
        } else {
            $null
        }
    }

    $JobList += [pscustomobject]$entry
}
```

---

## Export to CSV

```powershell
$exportPath = "C:\automation\updateuser_Jobs_allproperties_and_parameters.csv"
$JobList | Export-Csv -Path $exportPath -NoTypeInformation -Delimiter ";" -Encoding UTF8
```

---

## Result

After running the script, you’ll have a **CSV file** containing:

- Core job metadata (ID, status, times, runbook, worker, etc.)
- Every input parameter captured as its own column
- A uniform structure making filtering and pivots in Excel or Power BI effortless

Happy automating!

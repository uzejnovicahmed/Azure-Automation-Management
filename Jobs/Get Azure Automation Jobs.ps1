Connect-AzAccount
Set-AzContext "Subscription"

#Install-Module Az.Automation
Import-Module Az.Automation
# Set the variables from the previous job
$AutomationAccountName = 'AutomationAccountName'
$ResourceGroupName     = 'ResourceGroupname'
$Runbookname = "Your Runbook name"


# Get the previous job
$AutoAccount = @{
    AutomationAccountName = $AutomationAccountName
    ResourceGroupName     = $ResourceGroupName
}

# Calculate the start time (7 days ago from now)
$StartTime = (Get-Date).AddDays(-7)

#get all azureautomation Jobs from a specific Runbook
$Jobs = Get-AzAutomationJob @AutoAccount -RunbookName $RunbookName -StartTime $StartTime



#now we have the basic job data. But not all objects are containing data.
#because of that we need to get each job one by one and update the object with the necessary data.

$count = 0
$Jobscount = $Jobs.Count

foreach($Job in $Jobs)
{
$count++
Write-Output "$($count) from $($jobscount) Done -> JOBID : $($Job.Jobid)"
$automationjob = $null
$automationjob = Get-AzAutomationJob @AutoAccount -Id $Job.JobId
$job.JobParameters = $automationjob.JobParameters
$job.StatusDetails = $automationjob.StatusDetails
$job.StartedBy = $automationjob.StartedBy
$job.Exception = $automationjob.Exception
}




<#
#Collect all parameter names because the csv export will not list all values automatically. 
#To get sure we get all parameters we will create an object with all parameters
#>
$allParameterNames = @()

foreach ($job in $jobs) {
    if ($job.JobParameters) {
        $allParameterNames += $job.JobParameters.Keys
    }
}

$allParameterNames = $allParameterNames | Sort-Object -Unique

#Build a complete list of consistent objects

$JobList = @()

foreach ($job in $jobs) {
    $entry = [ordered]@{}
    $entry["JobId"] = $job.JobId
    $entry["JobId"] = $job.JobId
    $entry["CreationTime"] = $job.CreationTime
    $entry["Status"] = $job.Status
    $entry["StatusDetails"] = $job.StatusDetails
    $entry["StartTime"] = $job.StartTime
    $entry["EndTime"] = $job.EndTime
    $entry["Exception"] = $job.Exception
    $entry["RunbookName"] = $job.RunbookName
    $entry["HybridWorker"] = $job.HybridWorker
    $entry["StartedBy"] = $job.StartedBy

    foreach ($param in $allParameterNames) {
        $entry[$param] = if ($job.JobParameters.ContainsKey($param)) {
            $job.JobParameters[$param]
        } else {
            $null
        }
    }

    $JobList += [pscustomobject]$entry
}

Export to CSV with all columns
$exportpath =  "C:\automation\updateuser_Jobs_allproperties_and_parameters.csv"
$JobList | export-csv -Path $exportpath -NoTypeInformation -delimiter ";" -Encoding UTF8







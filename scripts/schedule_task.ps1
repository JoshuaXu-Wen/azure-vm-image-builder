# Create a scheduled task to run post_provision.ps1 at startup with SYSTEM user and highest privileges

$taskName = "RunPostProvision"
$scriptPath = "C:\scripts\\post_provision.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowsStyle Hidden -File $scriptPath"
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT1M" # Delay the task for 1 minute after startup to allow the system to stabilize
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force

Write-Host "Scheduled task '$taskName' created and registered successfully."
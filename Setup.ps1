<#
.SYNOPSIS
    Prepares the provisioning environment by creating necessary directories, moving provisioning files, setting registry entries, and scheduling follow-up scripts.

.DESCRIPTION
    This script sets up the provisioning folder and environment by:
      - Creating a dedicated provisioning directory under ProgramData.
      - Copying necessary provisioning files into the designated directory.
      - Removing the read-only attribute from copied files to ensure proper functionality.
      - Creating registry entries to track provisioning status.
      - Scheduling the next script (Set_Time.ps1) to automatically run once at the next system startup via the RunOnce registry key.

.FUNCTIONALITY
    - Creates "C:\ProgramData\provisioning" directory.
    - Copies required provisioning files to the new provisioning folder.
    - Removes read-only attributes recursively.
    - Creates and configures registry entries under "HKLM:\SOFTWARE\TeamLogic\Provisioning".
    - Sets a RunOnce registry entry to execute "Set_Time.ps1" at next system startup.

.NOTES
    - Requires Administrator privileges.
    - Tested on Windows 10 and Windows 11.
    - Logs actions to "C:\ProgramData\provisioning\provision_logs.txt".

.AUTHOR
    John Rediker

.DATE
    March 22, 2025
#>

# Prepare provisioning folder
$provisioning = New-Item "$($env:ProgramData)\provisioning" -ItemType Directory -Force

# Move files from provisioning package to provisioning folder
Get-ChildItem -File | Where-Object { $_.Name -notlike "init-*" } | ForEach-Object {
    Copy-Item $_.FullName "$($provisioning.FullName)\$($_.Name)" -Force
}

# Turn off Read-Only mode
attrib -r "$provisioning\*" /s

# Log file path
$logFile = "$provisioning\provision_logs.txt"

# Start Log Transcript
Start-Transcript -Path $logFile -Append -IncludeInvocationHeader

# Create Provisioning Registry Entry
$NewRegistryPath = "HKLM:\SOFTWARE\TeamLogic\Provisioning"
# Ensure the registry path exists
if (-not (Test-Path $NewRegistryPath)) {
    New-Item -Path $NewRegistryPath -Force
    Write-Output "Registry Path: $NewRegistryPath created successfully"
}

# Telling Windows to execute the Set_Time.ps1 script to run on next start up
$settings = [PSCustomObject]@{
    Path  = "SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    Name  = "set_time"
    Value = "cmd /c powershell.exe -ExecutionPolicy Bypass -File {0}\Set_Time.ps1" -f $provisioning.FullName
}

# Write the registry item
$registryPath = $settings.Path

# Try to open the registry key with write access
$registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($registryPath, $true)

# If the registry key does not exist, create it
if ($null -eq $registry) {
    try {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($registryPath)
        Write-Output "Created registry key: $registryPath"
    } catch {
        Write-Output "Error creating registry key: $_"
        return  # Exit the function if registry creation fails
    }
}

# Set the registry value
try {
    $registry.SetValue($settings.Name, $settings.Value, [Microsoft.Win32.RegistryValueKind]::String)
    Write-Output "Registry value set: $($settings.Name) = $($settings.Value)"
} catch {
    Write-Output "Failed to set registry value: $_"
}

# Dispose of the registry object
$registry.Dispose()

# Stop transcript when script finishes
Stop-Transcript
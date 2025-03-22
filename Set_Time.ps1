<#
.SYNOPSIS
    Sets execution policy, verifies network connectivity, configures power plan settings, prompts user for timezone selection via GUI, and synchronizes system time.

.DESCRIPTION
    This script performs several key provisioning steps:
      - Bypasses execution policy restrictions temporarily.
      - Initiates necessary initial configurations through external scripts.
      - Checks and waits for network connectivity before proceeding.
      - Provides a GUI for the user to select the appropriate timezone.
      - Configures automatic timezone updating and forces synchronization of system time.
      - Initiates subsequent provisioning scripts after timezone configuration.

.FUNCTIONALITY
    - Temporarily bypasses Execution Policy restrictions.
    - Verifies internet connectivity with continuous checks and prompts.
    - GUI interaction for timezone selection:
        * Eastern Standard Time
        * Central Standard Time
        * Mountain Standard Time
        * Pacific Standard Time
    - Enables automatic timezone updates via registry and service configuration.
    - Synchronizes system time immediately after timezone selection.

.NOTES
    - Requires Administrator privileges.
    - Tested on Windows 10 and Windows 11.
    - Logs actions to "C:\ProgramData\provisioning\provision_logs.txt".

.AUTHOR
    John Rediker

.DATE
    March 22, 2025
#>

# Bypass ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force

# Run init scripts
.\Init-PowerPlanConfig.ps1

# Log file path
$logFile = "$provisioning\provision_logs.txt"

# Start Log Transcript
Start-Transcript -Path $logFile -Append -IncludeInvocationHeader

# Set Provisioning path
$provisioning = [System.IO.DirectoryInfo]"$($env:ProgramData)\provisioning"

# First, check if network connectivity is available using .NET Ping
$pingObj = New-Object System.Net.NetworkInformation.Ping
$reply = $pingObj.Send("8.8.8.8", 2000)
$networkUp = ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)

if ($networkUp) {
    Write-Host "Network connectivity detected. Proceeding with the script..."
    # Continue with your script here...
} else {
    # No connectivity: show the popup and start a Timer to monitor connectivity
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Network Status"
    $form.Size = New-Object System.Drawing.Size(300, 120)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.ControlBox = $false
    $form.TopMost = $true

    # Create a label to show the status
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Waiting for network connection..."
    $label.Size = New-Object System.Drawing.Size(280, 30)
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($label)

    # Create a Timer to check connectivity every 5 seconds
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 5000

    $timer.Add_Tick({
        try {
            $pingObj = New-Object System.Net.NetworkInformation.Ping
            $reply = $pingObj.Send("8.8.8.8", 2000)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                # Network detected: stop timer, and close the form
                $timer.Stop()
                $form.Close()
            }
        } catch {
           # Log or display the error if ping operation fails
            Write-Warning "Network connectivity check failed: $_"
        }
    })

    # Start the timer and run the form
    $timer.Start()
    [System.Windows.Forms.Application]::Run($form)

    Write-Host "Network connectivity established. Continuing with the script..."
}


# Show Gui to select timezone
Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window  xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="Set Timezone" Height="auto" Width="auto" SizeToContent="WidthAndHeight" Topmost="True" ResizeMode="NoResize" >
    <StackPanel Orientation="Vertical" >
        <GroupBox Width="300" Margin="5" Padding="10" Header="Choose Time Zone">
            <StackPanel Orientation="Vertical">
                <TextBlock>Time Zone:</TextBlock>
                <ComboBox Name="TimeZoneComboBox" BorderBrush="Transparent">
                    <ComboBoxItem>Eastern Standard Time</ComboBoxItem>
                    <ComboBoxItem>Central Standard Time</ComboBoxItem>
                    <ComboBoxItem>Mountain Standard Time</ComboBoxItem>
                    <ComboBoxItem>Pacific Standard Time</ComboBoxItem>
                </ComboBox>
                <Button Name="ConfirmButton" Content="Confirm Selection" Margin="10" />
            </StackPanel>
        </GroupBox>
    </StackPanel>
</Window>
"@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

# Timezone change
$TimeZone = $window.FindName('TimeZoneComboBox')

$SeletTimeZoneButton = $window.FindName('ConfirmButton')

$SeletTimeZoneButton.Add_Click(
    {
        $selectedTimeZone = $TimeZone.SelectedItem.Content

        # Enable the time zone auto-update service
        Set-Service -Name tzautoupdate -StartupType Automatic
        Start-Service -Name tzautoupdate -ErrorAction SilentlyContinue

        # Set the registry key to enable automatic time zone
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name "Start" -Value 2

        # # Set Timezone
        Set-TimeZone -Id $selectedTimeZone

        # Restart the Windows Time Service
        Restart-Service w32time

        # Force sync time
        w32tm /resync

        $window.Close()

        # Run the Renaming Computer Script
        . "$($provisioning.FullName)\Rename_Computer.ps1" -ProvisioningFolder $provisioning.FullName
    }
)

$window.ShowDialog()

# Stop transcript when script finishes
Stop-Transcript
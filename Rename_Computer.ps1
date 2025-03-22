<#
.SYNOPSIS
    Provides a GUI interface to rename a computer and configure related provisioning registry entries.

.DESCRIPTION
    This script allows users to rename a computer through an interactive GUI, with an option for standard or non-standard naming conventions. It:
      - Presents a user-friendly GUI to input a new computer name.
      - Validates input to ensure a name is provided.
      - Sets registry keys for provisioning
      - Adds registry entries to run subsequent provisioning scripts on reboot.
      - Logs actions to assist with troubleshooting and provisioning auditing.

.FUNCTIONALITY
    - GUI prompts for computer renaming.
    - Validates that a computer name has been provided.
    - Renames computer immediately.
    - Sets required provisioning registry entries:
        * Next script execution (Remove_Preinstalled_Apps.ps1)
    - Automatically reboots the computer upon completion.

.NOTES
    - Requires Administrator privileges.
    - Tested on Windows 10 and Windows 11.
    - Logs provisioning actions to "C:\ProgramData\provisioning\provision_logs.txt".

.AUTHOR
    John Rediker

.DATE
    March 22, 2025
#>

# Bypass ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force

# Set Provisioning path
$provisioning = [System.IO.DirectoryInfo]"$($env:ProgramData)\provisioning"

# Log file path
$logFile = "$provisioning\provision_logs.txt"

# Start Log Transcript
Start-Transcript -Path $logFile -Append -IncludeInvocationHeader

Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window  xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="Rename Computer" Height="auto" Width="auto" SizeToContent="WidthAndHeight" Topmost="True" ResizeMode="NoResize" >
    <StackPanel Orientation="Vertical" >
        <GroupBox Width="300" Margin="5" Padding="10" Header="Change computer name">
            <StackPanel Orientation="Vertical" >
                <TextBlock>Computer name:</TextBlock>
                <TextBox Margin="0,0,0,10" Name="input_computer_name"></TextBox>
                <Button Name="button_rename_computer" Content="Change" />
            </StackPanel>
        </GroupBox>
    </StackPanel>
</Window>
"@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

# Computer name change

$input_computer_name = $window.FindName('input_computer_name')
$input_computer_name.Text = $env:COMPUTERNAME

$button_rename_computer = $window.FindName('button_rename_computer')


$button_rename_computer.Add_Click(
    {
        $rename = $input_computer_name.Text

        # Checks to see if the computer name is blank
        if ($rename -eq "") {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show("You must enter a computer name", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        Write-Host "Computer name: $rename"

        if ($isNonStandard -eq $false) {
            Rename-Computer $rename

            $config_items = @(
                [PSCustomObject]@{ # Execute Remove_Preinstalled_Apps.ps1
                    Path  = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                    Name  = "remove_preinstalled_apps"
                    Value = "cmd /c powershell.exe -ExecutionPolicy Bypass -File {0}\Remove_Preinstalled_Apps.ps1" -f $provisioning.FullName
                }
            )

            # Write each registry item
            foreach ($config_item in $config_items) {
                try {
                    # Check if the registry path exists, and create it if it doesn't
                    if (-not (Test-Path $config_item.Path)) {
                        New-Item -Path $config_item.Path -Force
                    }

                    # Create or update the registry value
                    New-ItemProperty -Path $config_item.Path -Name $config_item.Name -Value $config_item.Value -PropertyType String -Force
                } catch {
                    Write-Host "Error occurred while writing to the registry: $_"
                }
            }

            $window.Close()

            # Stop transcript when script finishes
            Stop-Transcript

            Restart-Computer
        } else {
            Rename-Computer $rename

            $config_items = @(
                [PSCustomObject]@{ # Remove_Preinstalled_Apps.ps1
                    Path  = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                    Name  = "remove_preinstalled_apps"
                    Value = "cmd /c powershell.exe -ExecutionPolicy Bypass -File {0}\Remove_Preinstalled_Apps.ps1" -f $provisioning.FullName
                }
            )

            # Write each registry item
            foreach ($config_item in $config_items) {
                try {
                    # Check if the registry path exists, and create it if it doesn't
                    if (-not (Test-Path $config_item.Path)) {
                        New-Item -Path $config_item.Path -Force
                    }

                    # Create or update the registry value
                    New-ItemProperty -Path $config_item.Path -Name $config_item.Name -Value $config_item.Value -PropertyType String -Force
                } catch {
                    Write-Host "Error occurred while writing to the registry: $_"
                }
            }

            $window.Close()

            # Stop transcript when script finishes
            Stop-Transcript

            Restart-Computer
        }
    }
)

$window.ShowDialog()
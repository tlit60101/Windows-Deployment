<#
.SYNOPSIS
    Removes pre-installed Dell and Microsoft software during provisioning.

.DESCRIPTION
    This script automates the removal of unwanted Dell utilities and pre-installed Microsoft Office applications during Windows provisioning. It includes registry-based uninstallation, removal of Windows Store apps, and package manager-based software removal.

.SOFTWARE REMOVED
    - Dell and SupportAssist-related services:
        * Dell SupportAssist
        * Dell Update
        * Dell Digital Delivery
        * Dell Customer Connect
        * Dell Power Manager
        * Any other applications matching "Dell" or "SupportAssist"

    - Pre-installed Microsoft applications:
        * Microsoft 365 (O365HomePremRetail - en-us, es-es, fr-fr, pt-br)
        * Microsoft OneNote (OneNoteFreeRetail - en-us, es-es, fr-fr, pt-br)

.KNOWN ISSUES
    - Some Dell applications may not fully uninstall if remnants remain in the registry or AppData folders.
    - Different versions of the Dell applications has different methods of uninstalling hince the different phases of uninstalling

.NOTES
    - Requires Administrator privileges.
    - Tested on Windows 10 and Windows 11.
    - Creates and appends logs in "C:\ProgramData\provisioning\provision_logs.txt".

.AUTHOR
    John Rediker

.DATE
    March 22, 2025
#>

# Set Provisioning path
$provisioning = [System.IO.DirectoryInfo]"$($env:ProgramData)\provisioning"

# Log file path
$logFile = "$provisioning\provision_logs.txt"

# Start Log Transcript
Start-Transcript -Path $logFile -Append -IncludeInvocationHeader

function Remove-DellServices {

    # Check if NuGet package provider is installed
    $nugetProvider = Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq "NuGet" }

    if ($nugetProvider) {
        Write-Host "NuGet package provider is already installed."
    } else {
        Write-Host "NuGet package provider not found. Installing..."
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers -ForceBootstrap

        # Verify installation
        $nugetProvider = Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq "NuGet" }
        if ($nugetProvider) {
            Write-Host "NuGet package provider installed successfully."
        } else {
            Write-Host "Failed to install NuGet package provider."
            return
        }
    }

    # PHASE 1 - Check Registry for Uninstall String

    # Define registry path
    $RegPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    # List of Dell services to check and uninstall
    $services = @(
        "*Dell*",
        "*SupportAssist*"
    )

    # Initialize array to collect results
    $DellServices = @()

    # Log start of Phase 1
    Write-Information "Starting Phase 1 - Registry Uninstall"

    # Iterate through each path
    foreach ($path in $RegPaths) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $props = Get-ItemProperty $_.PsPath
                    # Check for display name and either uninstall or quiet uninstall string
                    if ($props.DisplayName -and ($props.UninstallString -or $props.QuietUninstallString)) {
                        $UninstallString = if ($props.UninstallString) { $props.UninstallString } else { $props.QuietUninstallString }
                        $DellServices += [PSCustomObject]@{
                            Name = $props.DisplayName
                            UninstallString = $UninstallString
                        }
                    }
                } catch {
                    Write-Warning "Failed to read properties for $_.PsPath"
                }
            }
        } else {
            Write-Warning "Registry path not found: $path"
        }
    }

    # Initialize an array and a hash set to track unique names
    $ServicesToRemove = @()
    $UniqueNames = [System.Collections.Generic.HashSet[string]]::new()

    # Iterate through each service pattern
    foreach ($DellService in $services) {
        # Filter installed Dell software and add matches to the list
        $DellServices | Where-Object { $_.Name -like $DellService } | ForEach-Object {
            # Only add if not already present
            if ($UniqueNames.Add($_.Name)) {
                $ServicesToRemove += $_
            }
        }
    }

    # Display the services to be removed
    Write-Information $ServicesToRemove

    # Uninstall each software
    foreach ($service in $ServicesToRemove) {
        $uninstallCmd = $service.UninstallString
        Write-Host $uninstallCmd

        if (-not $uninstallCmd) {
            Write-Warning "No uninstall string for: $($service.Name)"
            continue
        }

        # Extract the path from quotes
        if ($uninstallCmd -match '^"([^"]+)"') {
            $filePath = $matches[1]
        } else {
            # If no quotes, assume everything before the first space is the path
            $filePath = ($uninstallCmd -split ' ')[0]
        }

        # Check if the file exists
        if (Test-Path $filePath) {
            Write-Output "Uninstalling: $($service.Name)"
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$uninstallCmd /quiet /norestart" -Wait -PassThru
        }
        else {
            Write-Warning "Uninstall file not found for: $($service.Name) - $filePath"
        }
    }


    # Phase 2 - Uninstall Windows App Packages

    # Log start of Phase 2
    Write-Information "Starting Phase 2 - Windows Apps Uninstall"

    # List all Windows Store Apps
    $appx_packages = "`n AppX Packages:`n" + (Get-AppxPackage | Out-String) + "`n"
    Write-Information $appx_packages

    foreach($service in $services) {
        # Get the package
        Get-AppxPackage -Name $service | ForEach-Object {
            Write-Output "Uninstalling: $($_.Name)"
            Remove-AppxPackage -Package $_.PackageFullName
        }
    }


    # Phase 3 - Uninstall Application Packages

    # Log start of Phase 3
    Write-Information "Starting Phase 3 - Application Packages Uninstall"

    # List all Windows Applications
    $app_packages = "App Packages:`n" + (Get-Package | Out-String) + "`n"
    Write-Information $app_packages

    foreach ($service in $services) {
        # Check if the package exists
        $package = Get-Package -Name $service -ErrorAction SilentlyContinue

        if ($package) {
            Write-Host "Found package: $package.Name. Uninstalling..."
            Uninstall-Package -Name $package.Name -Force -ErrorAction SilentlyContinue
            Write-Host "Successfully uninstalled: $package.Name"
        } else {
            Write-Host "Package not found: $service. Skipping..."
        }
    }
}

function Remove-PreInstalledMicrosoft {
    # Define registry path
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"

    # Define the versions we want to remove
    # $OfficeVersions = @(
    #     "O365HomePremRetail - en-us"
    #     "O365HomePremRetail - es-es"
    #     "O365HomePremRetail - fr-fr"
    #     "O365HomePremRetail - pt-br"
    #     "OneNoteFreeRetail - en-us"
    #     "OneNoteFreeRetail - es-es"
    #     "OneNoteFreeRetail - fr-fr"
    #     "OneNoteFreeRetail - pt-br"
    # )

    # Get all subkeys from the registry uninstall path
    $InstalledApps = Get-ChildItem -Path $RegPath | ForEach-Object {
        $AppName = (Get-ItemProperty $_.PsPath).DisplayName
        $UninstallString = (Get-ItemProperty $_.PsPath).UninstallString
        if ($AppName -and $UninstallString) {
            [PSCustomObject]@{
                Name = $AppName
                UninstallString = $UninstallString
            }
        }
    }

    # Filter installed Office versions
    $OfficeToRemove = $InstalledApps | Where-Object {
        $_.Name -match "Microsoft 365" -or $_.Name -match "Microsoft OneNote"
    }

    # Check if any version is installed
    if ($OfficeToRemove.Count -eq 0) {
        Write-Host "No matching Office versions found. Exiting..."
        return
    }

    # Total count for progress tracking
    $TotalVersions = $OfficeToRemove.Count
    $Current = 0

    # Uninstall each version
    foreach ($Office in $OfficeToRemove) {
        $Current++
        
        # Extract executable and arguments
        $UninstallParts = $Office.UninstallString -split '" ', 2
        $ExePath = $UninstallParts[0] -replace '"', ''  # Remove extra quotes
        $Arguments = $UninstallParts[1] + " displaylevel=false"  # Append silent uninstall flag

        Write-Host "Uninstalling: $($Office.Name)..."

        # Start uninstallation in a background job
        $job = Start-Job -ScriptBlock {
            Start-Process -FilePath $using:ExePath -ArgumentList $using:Arguments -NoNewWindow -Wait
        }

        # Show progress bar while uninstalling
        while ($job.State -eq "Running") {
            $PercentComplete = [math]::Round(($Current / $TotalVersions) * 100)
            Write-Progress -Activity "Uninstalling Office Versions" -Status "Removing: $($Office.Name) ($Current of $TotalVersions)" -PercentComplete $PercentComplete
            Start-Sleep -Seconds 2
        }

        # Cleanup job
        Receive-Job -Job $job
        Remove-Job -Job $job

        Write-Host "$($Office.Name) uninstalled successfully."
    }
}

# Run Functions
Remove-DellServices
Remove-PreInstalledMicrosoft

# Stop transcript when script finishes
Stop-Transcript

# Display message once everything is completed
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("The provisioning package has completed setup", "Setup Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
# Windows Configuration Designer Setup Guide

This document details how to download and install Windows Configuration Designer (WCD), create an advanced deployment package, and deploy it during Windows setup. Included is a test deployment package (`.ppkg`) that you can open within Windows Configuration Designer and configure according to your needs.

---

## Download Windows Configuration Designer

You can download WCD in two ways:

### Option 1: Microsoft Store
1. Open the **Microsoft Store** app.
2. Search for **"Windows Configuration Designer"**.
3. Click **Get** or **Install** to download.

### Option 2: Direct Link
1. Visit [this link](https://apps.microsoft.com/detail/9NBLGGH4TX22?hl=en-us&gl=US&ocid=pdpshare).
2. Click **Get in Store app**.
3. Follow prompts to install.

---

## RECOMMENDATIONS

1. Keep the deployment package lite. Let your RMM and/or other tools do all the heavy lifting (Install applications, windows updates, etc)
2. Logging is just output from the terminal. I recommend creating a logging function to replace the current one. I have that on my list of improvements to work on in the future.

---

## Using the Test Deployment Package

A test deployment package (`TestDeployment.ppkg`) is provided with this guide. This is not meant to be deployed straight away. Please go through and add/modify the settings. To use this test package:

1. Open **Windows Configuration Designer**.
2. Select **Open a project** and browse to the provided `TestDeployment.ppkg`.
3. Modify or customize the settings as necessary.

---

## Create a Deployment Package (Advanced Settings)

To create a new deployment package from scratch:

1. Launch **Windows Configuration Designer**.
2. Select **Advanced provisioning**.
3. Choose your provisioning package type (Desktop, Mobile, Kiosk).
4. Click **Next** to configure advanced options.

### Detailed Settings:

#### Accounts
- Specify user accounts clearly.
  - Example: Username: `Admin`
  - Password: `SecurePass123!`
- Optionally configure auto-login settings.

#### Hide OOBE (Out-of-Box Experience)
- Enable the option to bypass or hide OOBE setup screens.

#### Provisioning Commands
Provisioning commands let you execute custom scripts or registry edits during deployment.

- **Example Command:** Disable Privacy Experience

```batch
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE /v DisablePrivacyExperience /t REG_DWORD /d 1
```

### Additional Configuration Options:

- **Applications:** Include apps that you want automatically installed or removed during provisioning.
- **Certificates:** Add required certificates for your organization.
- **Policies:** Apply custom policies to manage device behavior, security, and privacy settings.
- **Wi-Fi Profiles:** Configure Wi-Fi network details for automatic connection.

5. Once your settings are completed, click **Export**.
6. Provide a name for your provisioning package and choose a location to save.
7. Click **Build** to generate the `.ppkg` provisioning file.

Your deployment package (`.ppkg`) is now ready for use.

---

## Deploying Your Provisioning Package

Deploy the created package by following these steps:

1. Copy your provisioning package file (`.ppkg`) onto a USB drive.
2. Insert the USB drive into the target computer **during the initial Windows setup wizard** (when setting up Windows for the first time).
3. Windows will automatically detect your provisioning package from the USB.
4. Follow the on-screen instructions to apply your provisioning package and complete the setup.

---

For further reference, please see the [official Microsoft documentation](https://docs.microsoft.com/windows/configuration/provisioning-packages/provisioning-packages).


<#
.SYNOPSIS
    Configures power settings on Windows devices to disable standby and hibernation, set monitor timeout to 10 minutes, and configure lid actions to "Sleep"

.DESCRIPTION
    This script applies specific power configuration settings:
      - Monitor timeout: Set to 10 minutes for both AC (plugged-in) and DC (battery-powered) modes.
      - Standby and Hibernate: Disabled (set to "never") in both AC and DC modes.
      - Lid action: Configured to "Do nothing" when closed, in both AC and DC modes.

.NOTES
    - Requires administrator privileges.
    - Tested on Windows 10 and Windows 11.
    - Can be executed directly via PowerShell with elevated privileges.

.AUTHOR
    John Rediker

.DATE
    March 22, 2025
#>

"powercfg /x -monitor-timeout-ac 10",
"powercfg /x -standby-timeout-ac 0",
"powercfg /x -hibernate-timeout-ac 0",
"powercfg /x -monitor-timeout-dc 10",
"powercfg /x -standby-timeout-dc 0",
"powercfg /x -hibernate-timeout-dc 0",
"powercfg /setACvalueIndex scheme_current sub_buttons lidAction 1",
"powercfg /setDCvalueIndex scheme_current sub_buttons lidAction 1",
"powercfg /setActive scheme_current" | ForEach-Object {
    cmd /c $_
}
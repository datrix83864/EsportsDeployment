# Windows 11 Optimization Script
# High School Esports LAN Infrastructure
# Optimizes Windows for gaming performance and tournament use

Write-Host "Starting Windows Optimization..." -ForegroundColor Green

# Disable UAC (for tournament ease of use)
Write-Host "Configuring UAC..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0

# Disable Cortana
Write-Host "Disabling Cortana..." -ForegroundColor Yellow
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "Windows Search" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0

# Disable Windows Search Indexing (optional - improves SSD life)
Write-Host "Optimizing Windows Search..." -ForegroundColor Yellow
Stop-Service "WSearch" -WarningAction SilentlyContinue
Set-Service "WSearch" -StartupType Disabled

# Disable Telemetry
Write-Host "Disabling telemetry..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Force

# Disable OneDrive
Write-Host "Disabling OneDrive..." -ForegroundColor Yellow
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1 -Force

# Enable Gaming Mode
Write-Host "Enabling Gaming Mode..." -ForegroundColor Yellow
New-Item -Path "HKCU:\Software\Microsoft\GameBar" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1

# Set High Performance Power Plan
Write-Host "Setting High Performance Power Plan..." -ForegroundColor Yellow
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Disable unnecessary visual effects
Write-Host "Optimizing visual effects..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2

# Disable Windows Update Automatic Restart
Write-Host "Configuring Windows Update..." -ForegroundColor Yellow
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AU" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 2 -Force

# Disable Hibernate (saves disk space)
Write-Host "Disabling hibernation..." -ForegroundColor Yellow
powercfg /hibernate off

# Disable System Restore (we reimage anyway)
Write-Host "Disabling System Restore..." -ForegroundColor Yellow
Disable-ComputerRestore -Drive "C:\"

# Optimize network settings for gaming
Write-Host "Optimizing network settings..." -ForegroundColor Yellow
# Disable Nagle's Algorithm
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpAckFrequency" -Value 1 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPNoDelay" -Value 1 -Force

# Disable unnecessary services
Write-Host "Disabling unnecessary services..." -ForegroundColor Yellow
$services = @(
    "DiagTrack",                # Connected User Experiences and Telemetry
    "dmwappushservice",         # WAP Push Message Routing Service
    "RetailDemo",               # Retail Demo Service
    "XblAuthManager",           # Xbox Live Auth Manager (if not using Xbox features)
    "XblGameSave",              # Xbox Live Game Save
    "XboxNetApiSvc",            # Xbox Live Networking Service
    "SysMain",                  # Superfetch (can disable on SSD)
    "WSearch"                   # Windows Search (already done above)
)

foreach ($service in $services) {
    try {
        Stop-Service $service -Force -ErrorAction SilentlyContinue
        Set-Service $service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  Disabled: $service" -ForegroundColor Gray
    } catch {
        Write-Host "  Could not disable: $service" -ForegroundColor DarkYellow
    }
}

# Disable Windows Defender (for performance during tournaments)
Write-Host "Disabling Windows Defender..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -PropertyType DWORD -Force

# Disable automatic maintenance
Write-Host "Disabling automatic maintenance..." -ForegroundColor Yellow
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name "MaintenanceDisabled" -Value 1 -PropertyType DWORD -Force

# Optimize SSD (if present)
Write-Host "Optimizing for SSD..." -ForegroundColor Yellow
fsutil behavior set DisableLastAccess 1
fsutil behavior set EncryptPagingFile 0

# Disable unnecessary startup programs
Write-Host "Disabling startup programs..." -ForegroundColor Yellow
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "*" -ErrorAction SilentlyContinue

# Set DNS servers (LANCache first, then fallback)
Write-Host "Configuring DNS servers..." -ForegroundColor Yellow
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
if ($adapter) {
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ("192.168.1.11","8.8.8.8")
    Write-Host "  DNS configured for LANCache" -ForegroundColor Gray
}

# Disable Windows Tips and Suggestions
Write-Host "Disabling Windows tips..." -ForegroundColor Yellow
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0 -PropertyType DWORD -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0

# Disable Background Apps
Write-Host "Disabling background apps..." -ForegroundColor Yellow
Get-AppxPackage -AllUsers | Where-Object {$_.Name -notlike "*Store*" -and $_.Name -notlike "*Calculator*"} | ForEach-Object {
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\$($_.PackageFamilyName)" -Name "Disabled" -Value 1 -ErrorAction SilentlyContinue
    } catch {}
}

# Configure Windows Explorer
Write-Host "Configuring Windows Explorer..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Value 0

# Disable Game DVR
Write-Host "Disabling Game DVR..." -ForegroundColor Yellow
New-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -PropertyType DWORD -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -PropertyType DWORD -Force

# Set time zone
Write-Host "Setting timezone..." -ForegroundColor Yellow
Set-TimeZone -Id "Eastern Standard Time"

# Enable Network Discovery
Write-Host "Enabling network discovery..." -ForegroundColor Yellow
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes

# Enable File Sharing
Write-Host "Enabling file sharing..." -ForegroundColor Yellow
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

# Disable SmartScreen
Write-Host "Disabling SmartScreen..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force

# Clean up Windows Update files
Write-Host "Cleaning Windows Update cache..." -ForegroundColor Yellow
Stop-Service wuauserv -Force
Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service wuauserv

# Optimize Windows Defender exclusions for game folders
Write-Host "Adding game folder exclusions..." -ForegroundColor Yellow
Add-MpPreference -ExclusionPath "G:\SteamLibrary" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "G:\EpicGames" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "G:\RiotGames" -ErrorAction SilentlyContinue

# Disable Windows Insider Program
Write-Host "Disabling Windows Insider..." -ForegroundColor Yellow
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds" -Name "AllowBuildPreview" -Value 0 -PropertyType DWORD -Force

# Disable Delivery Optimization
Write-Host "Disabling Delivery Optimization..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0 -Force

# Create desktop shortcuts folder
Write-Host "Creating shortcuts folder..." -ForegroundColor Yellow
New-Item -Path "C:\Users\Public\Desktop\Games" -ItemType Directory -Force | Out-Null

# Set taskbar settings
Write-Host "Configuring taskbar..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0

# Disable Cortana button
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCortanaButton" -Value 0

# Registry tweaks for better game performance
Write-Host "Applying gaming registry tweaks..." -ForegroundColor Yellow

# GPU priority for games
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "GPU Priority" -Value 8
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Priority" -Value 6
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Scheduling Category" -Value "High"

# Disable fullscreen optimizations globally
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Value 2
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1

Write-Host ""
Write-Host "Optimization complete!" -ForegroundColor Green
Write-Host "System optimized for gaming performance" -ForegroundColor Green
Write-Host ""

# Create optimization report
$report = @"
Windows Optimization Report
===========================
Date: $(Get-Date)

Optimizations Applied:
- UAC disabled for ease of use
- Cortana disabled
- Windows Search optimized
- Telemetry disabled
- OneDrive disabled
- Gaming Mode enabled
- High Performance power plan set
- Visual effects optimized
- Windows Update auto-restart disabled
- Hibernation disabled
- System Restore disabled
- Network optimized for gaming
- Unnecessary services disabled
- Windows Defender disabled (tournament mode)
- DNS configured for LANCache (192.168.1.11)
- Background apps disabled
- Game DVR disabled
- SmartScreen disabled
- Game folder exclusions added

Next Steps:
1. Install applications (install_apps.ps1)
2. Configure roaming profiles (configure_profiles.ps1)
3. Sysprep and capture image

"@

$report | Out-File "C:\Setup\optimization_report.txt"
Write-Host "Report saved to C:\Setup\optimization_report.txt" -ForegroundColor Cyan
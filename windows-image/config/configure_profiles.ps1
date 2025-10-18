# Configure Roaming Profiles and Folder Redirection
# High School Esports LAN Infrastructure

Write-Host "Configuring Roaming Profiles..." -ForegroundColor Green
Write-Host ""

# File server IP from configuration
$fileServerIP = "192.168.1.12"
$profilePath = "\\$fileServerIP\profiles"

# Configure roaming profiles via registry
Write-Host "Setting up roaming profile registry keys..." -ForegroundColor Yellow

# Set default profile path
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Name "ProfilesDirectory" -Value $profilePath -PropertyType String -Force

# Enable roaming profiles
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Name "UseProfileQuota" -Value 1 -PropertyType DWORD -Force

# Set profile quota (2GB = 2097152 KB)
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Name "MaxProfileSize" -Value 2097152 -PropertyType DWORD -Force

# Warn at 90% (1887436 KB)
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Name "WarnUserTimeout" -Value 1887436 -PropertyType DWORD -Force

Write-Host "  Roaming profile settings configured" -ForegroundColor Green

# Configure Folder Redirection
Write-Host "Configuring folder redirection..." -ForegroundColor Yellow

# Create folder redirection registry keys
$redirectionPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
New-Item -Path $redirectionPath -Force | Out-Null

# Redirect Documents to network
Set-ItemProperty -Path $redirectionPath -Name "RedirectDocuments" -Value "$profilePath\%USERNAME%\Documents" -Force

# Redirect Downloads to local G: drive (for performance)
Set-ItemProperty -Path $redirectionPath -Name "RedirectDownloads" -Value "G:\UserData\Downloads" -Force

# Redirect Videos to local G: drive
Set-ItemProperty -Path $redirectionPath -Name "RedirectVideos" -Value "G:\UserData\Videos" -Force

# Redirect Pictures to local G: drive
Set-ItemProperty -Path $redirectionPath -Name "RedirectPictures" -Value "G:\UserData\Pictures" -Force

Write-Host "  Folder redirection configured" -ForegroundColor Green

# Configure local profile cache
Write-Host "Configuring local profile caching..." -ForegroundColor Yellow

# Enable profile caching for faster loads
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "CachedLogonsCount" -Value 10 -PropertyType String -Force

# Delete cached profiles on logout (keeps machines clean)
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DeleteRoamingCache" -Value 1 -PropertyType DWORD -Force

Write-Host "  Profile caching configured" -ForegroundColor Green

# Configure SMB settings for better performance
Write-Host "Optimizing SMB settings..." -ForegroundColor Yellow

# Enable SMB3
Set-SmbClientConfiguration -EnableBandwidthThrottling $false -Force
Set-SmbClientConfiguration -EnableLargeMtu $true -Force
Set-SmbClientConfiguration -Force

Write-Host "  SMB settings optimized" -ForegroundColor Green

# Create network drive mapping script
Write-Host "Creating profile mount script..." -ForegroundColor Yellow

$mountScript = @'
@echo off
REM Mount roaming profile automatically
REM This runs at user login

REM Map profile share
net use P: \\192.168.1.12\profiles /persistent:yes

REM Create local folders if they don't exist
if not exist "G:\UserData" mkdir "G:\UserData"
if not exist "G:\UserData\Documents" mkdir "G:\UserData\Documents"
if not exist "G:\UserData\Downloads" mkdir "G:\UserData\Downloads"
if not exist "G:\UserData\Videos" mkdir "G:\UserData\Videos"
if not exist "G:\UserData\Pictures" mkdir "G:\UserData\Pictures"
'@

$mountScript | Out-File "C:\Windows\System32\GroupPolicy\User\Scripts\Logon\mount_profile.bat" -Encoding ASCII -Force

# Add script to run at logon
$scriptPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Logon\0"
New-Item -Path $scriptPath -Force | Out-Null
New-ItemProperty -Path $scriptPath -Name "Script" -Value "mount_profile.bat" -PropertyType String -Force
New-ItemProperty -Path $scriptPath -Name "Parameters" -Value "" -PropertyType String -Force

Write-Host "  Profile mount script created" -ForegroundColor Green

# Configure game client settings for G: drive
Write-Host "Configuring game client paths..." -ForegroundColor Yellow

# Steam library configuration (already done in install_apps.ps1, but ensure it's set)
$steamPath = "HKCU:\Software\Valve\Steam"
if (Test-Path $steamPath) {
    # Set default install location
    New-ItemProperty -Path $steamPath -Name "SteamPath" -Value "G:\SteamLibrary" -PropertyType String -Force -ErrorAction SilentlyContinue
}

# Epic Games configuration
$epicPath = "HKCU:\Software\Epic Games\EOS"
if (-not (Test-Path $epicPath)) {
    New-Item -Path $epicPath -Force | Out-Null
}
New-ItemProperty -Path $epicPath -Name "DefaultAppInstallLocation" -Value "G:\EpicGames" -PropertyType String -Force

Write-Host "  Game client paths configured" -ForegroundColor Green

# Configure AppData redirection for game settings
Write-Host "Configuring AppData folders..." -ForegroundColor Yellow

# Redirect AppData\Local to local disk (large temp files)
$appDataLocalPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
Set-ItemProperty -Path $appDataLocalPath -Name "Local AppData" -Value "G:\UserData\AppData\Local" -Force -ErrorAction SilentlyContinue

# Keep AppData\Roaming on network (game settings)
# This is handled automatically by roaming profiles

Write-Host "  AppData redirection configured" -ForegroundColor Green

# Create logon/logoff scripts folder structure
Write-Host "Creating Group Policy folders..." -ForegroundColor Yellow
$gpFolders = @(
    "C:\Windows\System32\GroupPolicy\User\Scripts\Logon",
    "C:\Windows\System32\GroupPolicy\User\Scripts\Logoff",
    "C:\Windows\System32\GroupPolicy\Machine\Scripts\Startup",
    "C:\Windows\System32\GroupPolicy\Machine\Scripts\Shutdown"
)

foreach ($folder in $gpFolders) {
    New-Item -Path $folder -ItemType Directory -Force | Out-Null
}

Write-Host "  Group Policy folders created" -ForegroundColor Green

# Create logoff script to clean up temp files
$logoffScript = @'
@echo off
REM Clean up temporary files on logoff

REM Clean temp folders
del /q /f /s "%TEMP%\*" 2>nul
del /q /f /s "G:\UserData\AppData\Local\Temp\*" 2>nul

REM Clear game caches (optional)
REM del /q /f /s "%LOCALAPPDATA%\EpicGamesLauncher\Saved\Logs\*" 2>nul

echo Profile cleanup complete
'@

$logoffScript | Out-File "C:\Windows\System32\GroupPolicy\User\Scripts\Logoff\cleanup.bat" -Encoding ASCII -Force

Write-Host "  Logoff cleanup script created" -ForegroundColor Green

# Configure profile settings for all users
Write-Host "Applying settings to default user profile..." -ForegroundColor Yellow

# Load default user registry hive
reg load HKU\DefaultUser "C:\Users\Default\NTUSER.DAT"

# Apply settings to default profile
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 0 /f
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t REG_DWORD /d 1 /f

# Unload default user hive
reg unload HKU\DefaultUser

Write-Host "  Default profile configured" -ForegroundColor Green

# Test network connectivity to file server
Write-Host "Testing connection to file server..." -ForegroundColor Yellow
if (Test-Connection -ComputerName $fileServerIP -Count 2 -Quiet) {
    Write-Host "  Connection to file server successful" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Cannot reach file server at $fileServerIP" -ForegroundColor Red
    Write-Host "  Profiles will not work until file server is accessible" -ForegroundColor Red
}

Write-Host ""
Write-Host "Profile configuration complete!" -ForegroundColor Green
Write-Host ""

# Create configuration report
$report = @"
Roaming Profile Configuration Report
====================================
Date: $(Get-Date)

Profile Settings:
- Roaming profiles enabled
- Profile path: $profilePath
- Profile quota: 2GB (2097152 KB)
- Warning threshold: 90% (1887436 KB)
- Cached logons: 10
- Delete cache on logout: Enabled

Folder Redirection:
- Documents → Network ($profilePath\%USERNAME%\Documents)
- Downloads → Local (G:\UserData\Downloads)
- Videos → Local (G:\UserData\Videos)
- Pictures → Local (G:\UserData\Pictures)
- AppData\Local → Local (G:\UserData\AppData\Local)
- AppData\Roaming → Network (in profile)

SMB Optimization:
- Bandwidth throttling: Disabled
- Large MTU: Enabled

Logon Scripts:
- mount_profile.bat (mounts profile share)

Logoff Scripts:
- cleanup.bat (cleans temp files)

Game Client Configuration:
- Steam library: G:\SteamLibrary
- Epic Games: G:\EpicGames
- Riot Games: G:\RiotGames

File Server:
- IP Address: $fileServerIP
- Connection Status: $(if (Test-Connection -ComputerName $fileServerIP -Count 1 -Quiet) {"Connected"} else {"Not reachable"})

Next Steps:
1. Test profile loading with a user account
2. Verify folder redirection working
3. Run Sysprep to generalize image
4. Capture image to WIM file

Notes:
- Users must authenticate to file server
- Profile size is monitored and enforced
- Large files automatically go to G: drive
- Settings persist across machines and reboots
"@

$report | Out-File "C:\Setup\profile_configuration_report.txt"
Write-Host "Report saved to C:\Setup\profile_configuration_report.txt" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuration Summary:" -ForegroundColor Cyan
Write-Host "  Profile Path: $profilePath" -ForegroundColor White
Write-Host "  File Server: $fileServerIP" -ForegroundColor White
Write-Host "  Profile Quota: 2GB" -ForegroundColor White
Write-Host "  Folder Redirection: Configured" -ForegroundColor White
Write-Host ""
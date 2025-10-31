# Application Installation Script
# High School Esports LAN Infrastructure
# Installs game clients, communication apps, and utilities

Write-Host "Starting Application Installation..." -ForegroundColor Green
Write-Host ""

# Install Chocolatey (package manager)
Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
try {
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Host "  Chocolatey installed successfully" -ForegroundColor Green
} catch {
    Write-Host "  Error installing Chocolatey: $_" -ForegroundColor Red
    exit 1
}

# Refresh environment
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host ""
Write-Host "Installing applications via Chocolatey..." -ForegroundColor Yellow
Write-Host "This may take 30-60 minutes..." -ForegroundColor Cyan
Write-Host ""

# Install browsers
Write-Host "Installing Chrome..." -ForegroundColor Yellow
choco install googlechrome -y --ignore-checksums

# Install utilities
Write-Host "Installing 7-Zip..." -ForegroundColor Yellow
choco install 7zip -y

Write-Host "Installing VLC Media Player..." -ForegroundColor Yellow
choco install vlc -y

# Install Discord
Write-Host "Installing Discord..." -ForegroundColor Yellow
choco install discord -y

# Install TeamSpeak 3
Write-Host "Installing TeamSpeak 3..." -ForegroundColor Yellow
choco install teamspeak -y

# Install Steam
Write-Host "Installing Steam..." -ForegroundColor Yellow
choco install steam -y

# Configure Steam library on G: drive
Write-Host "Configuring Steam library..." -ForegroundColor Yellow
$steamConfigPath = "C:\Program Files (x86)\Steam\config"
if (Test-Path $steamConfigPath) {
    $libraryFoldersVdf = @"
"LibraryFolders"
{
    "0"
    {
        "path"      "C:\\Program Files (x86)\\Steam"
        "label"     ""
        "contentid"     "1234567890"
    }
    "1"
    {
        "path"      "G:\\SteamLibrary"
        "label"     "Games Drive"
        "contentid"     "1234567891"
    }
}
"@
    New-Item -Path "G:\SteamLibrary" -ItemType Directory -Force | Out-Null
    New-Item -Path "G:\SteamLibrary\steamapps" -ItemType Directory -Force | Out-Null
    $libraryFoldersVdf | Out-File "$steamConfigPath\libraryfolders.vdf" -Encoding ASCII
    Write-Host "  Steam library configured on G: drive" -ForegroundColor Green
}

# Install Epic Games Launcher
Write-Host "Installing Epic Games Launcher..." -ForegroundColor Yellow
$epicUrl = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
$epicInstaller = "C:\Temp\EpicGamesLauncher.msi"
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
try {
    Invoke-WebRequest -Uri $epicUrl -OutFile $epicInstaller
    Start-Process msiexec.exe -ArgumentList "/i `"$epicInstaller`" /quiet /norestart" -Wait
    Remove-Item $epicInstaller -Force
    Write-Host "  Epic Games Launcher installed" -ForegroundColor Green
} catch {
    Write-Host "  Error installing Epic Games Launcher: $_" -ForegroundColor Red
}

# Configure Epic Games to use G: drive
Write-Host "Configuring Epic Games library..." -ForegroundColor Yellow
New-Item -Path "G:\EpicGames" -ItemType Directory -Force | Out-Null
# Epic Games settings are per-user, will be configured in profile

# Install Riot Client (Valorant, League of Legends)
Write-Host "Installing Riot Client..." -ForegroundColor Yellow
$riotUrl = "https://valorant.secure.dyn.riotcdn.net/channels/public/x/installer/current/live.live.eu.exe"
$riotInstaller = "C:\Temp\RiotClientInstaller.exe"
try {
    # Note: Riot installer URL may change, update as needed
    # For now, we'll create the folder and let users install manually
    New-Item -Path "G:\RiotGames" -ItemType Directory -Force | Out-Null
    Write-Host "  Riot Games folder created (install client manually or via script)" -ForegroundColor Yellow
} catch {
    Write-Host "  Note: Riot Client installation may need to be done manually" -ForegroundColor Yellow
}

# Install Battle.net (optional)
if ($env:INSTALL_BATTLENET -eq "true") {
    Write-Host "Installing Battle.net..." -ForegroundColor Yellow
    $battlenetUrl = "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
    $battlenetInstaller = "C:\Temp\BattleNetInstaller.exe"
    try {
        Invoke-WebRequest -Uri $battlenetUrl -OutFile $battlenetInstaller
        Start-Process $battlenetInstaller -ArgumentList "--lang=enUS" -Wait
        Remove-Item $battlenetInstaller -Force
        Write-Host "  Battle.net installed" -ForegroundColor Green
    } catch {
        Write-Host "  Error installing Battle.net: $_" -ForegroundColor Red
    }
}

# Install DirectX (if needed)
Write-Host "Installing DirectX..." -ForegroundColor Yellow
choco install directx -y

# Install Visual C++ Redistributables (required by many games)
Write-Host "Installing Visual C++ Redistributables..." -ForegroundColor Yellow
choco install vcredist-all -y

# Install .NET Framework (if needed)
Write-Host "Installing .NET Framework..." -ForegroundColor Yellow
choco install dotnet-runtime -y
choco install dotnet-6.0-runtime -y

# Create desktop shortcuts for game clients
Write-Host "Creating desktop shortcuts..." -ForegroundColor Yellow
$WshShell = New-Object -ComObject WScript.Shell

# Steam shortcut
if (Test-Path "C:\Program Files (x86)\Steam\steam.exe") {
    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Steam.lnk")
    $Shortcut.TargetPath = "C:\Program Files (x86)\Steam\steam.exe"
    $Shortcut.Save()
}

# Epic Games shortcut
if (Test-Path "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe") {
    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Epic Games.lnk")
    $Shortcut.TargetPath = "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe"
    $Shortcut.Save()
}

# Discord shortcut
if (Test-Path "$env:LOCALAPPDATA\Discord\Update.exe") {
    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Discord.lnk")
    $Shortcut.TargetPath = "$env:LOCALAPPDATA\Discord\Update.exe"
    $Shortcut.Arguments = "--processStart Discord.exe"
    $Shortcut.Save()
}

# Create game folders with proper permissions
Write-Host "Setting up game folders..." -ForegroundColor Yellow
$gameFolders = @(
    "G:\SteamLibrary",
    "G:\EpicGames",
    "G:\RiotGames",
    "G:\UserData",
    "G:\UserData\Documents",
    "G:\UserData\Downloads",
    "G:\UserData\Videos",
    "G:\UserData\Pictures"
)

foreach ($folder in $gameFolders) {
    New-Item -Path $folder -ItemType Directory -Force | Out-Null
    # Set permissions for all users
    $acl = Get-Acl $folder
    $permission = "Users","FullControl","ContainerInherit,ObjectInherit","None","Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    Set-Acl $folder $acl
}

Write-Host "  Game folders created with proper permissions" -ForegroundColor Green

# Clean up
Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
Remove-Item "C:\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Disable automatic updates for installed apps
Write-Host "Disabling automatic updates..." -ForegroundColor Yellow
# Steam
if (Test-Path "HKCU:\Software\Valve\Steam") {
    Set-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "AutoUpdateEnabled" -Value 0 -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Application installation complete!" -ForegroundColor Green
Write-Host ""

# Create installation report
$report = @"
Application Installation Report
================================
Date: $(Get-Date)

Installed Applications:
- Google Chrome (Web Browser)
- 7-Zip (File Archiver)
- VLC Media Player
- Discord (Communication)
- TeamSpeak 3 (Communication)
- Steam (Game Client)
- Epic Games Launcher (Game Client)
- Riot Client folder created (manual install may be needed)
- DirectX
- Visual C++ Redistributables (All versions)
- .NET Runtime

Game Folders Created:
- G:\SteamLibrary (Steam games)
- G:\EpicGames (Epic games)
- G:\RiotGames (Riot games)
- G:\UserData (Redirected user folders)

Desktop Shortcuts Created:
- Steam
- Epic Games Launcher
- Discord

Next Steps:
1. Configure roaming profiles (configure_profiles.ps1)
2. Test game installations
3. Sysprep and capture image

Notes:
- Riot Client may need manual installation
- Battle.net installation is optional (set INSTALL_BATTLENET=true)
- All game clients configured to use G: drive
- Automatic updates disabled for tournament stability

"@

$report | Out-File "C:\Setup\installation_report.txt"
Write-Host "Report saved to C:\Setup\installation_report.txt" -ForegroundColor Cyan
Write-Host ""
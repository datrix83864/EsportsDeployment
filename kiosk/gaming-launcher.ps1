# Gaming Kiosk Shell
# High School Esports LAN Infrastructure
#
# Replaces Windows shell with a custom gaming launcher
# Prevents users from accessing Windows directly
#
# To enable: Set as Windows shell in registry

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Configuration
$CONFIG = @{
    OrgName = "High School Esports"
    BackgroundColor = "#1a1a2e"
    AccentColor = "#0f3460"
    HighlightColor = "#16213e"
    TextColor = "#eaeaea"
}

# Define available games and applications
$GAMES = @(
    @{
        Name = "Fortnite"
        Icon = "🎮"
        Launcher = "Epic"
        Path = "com.epicgames.launcher://apps/Fortnite?action=launch"
        Color = "#00D9FF"
    },
    @{
        Name = "Rocket League"
        Icon = "🚗"
        Launcher = "Epic"
        Path = "com.epicgames.launcher://apps/RocketLeague?action=launch"
        Color = "#FFA000"
    },
    @{
        Name = "Valorant"
        Icon = "🎯"
        Launcher = "Riot"
        Path = "C:\Riot Games\Riot Client\RiotClientServices.exe --launch-product=valorant"
        Color = "#FF4655"
    },
    @{
        Name = "League of Legends"
        Icon = "⚔️"
        Launcher = "Riot"
        Path = "C:\Riot Games\Riot Client\RiotClientServices.exe --launch-product=league_of_legends"
        Color = "#0AC8B9"
    },
    @{
        Name = "Overwatch 2"
        Icon = "🎮"
        Launcher = "Battle.net"
        Path = "C:\Program Files (x86)\Battle.net\Battle.net.exe --game=ow2"
        Color = "#F99E1A"
    },
    @{
        Name = "Steam Library"
        Icon = "🎮"
        Launcher = "Steam"
        Path = "steam://open/games"
        Color = "#1B2838"
    }
)

$UTILITIES = @(
    @{
        Name = "Discord"
        Icon = "💬"
        Path = "$env:LOCALAPPDATA\Discord\Update.exe --processStart Discord.exe"
        Color = "#5865F2"
    },
    @{
        Name = "TeamSpeak"
        Icon = "🎙️"
        Path = "C:\Program Files\TeamSpeak 3 Client\ts3client_win64.exe"
        Color = "#2580C3"
    },
    @{
        Name = "Audio Settings"
        Icon = "🔊"
        Action = "audio"
        Color = "#4CAF50"
    },
    @{
        Name = "Bluetooth"
        Icon = "📶"
        Action = "bluetooth"
        Color = "#2196F3"
    }
)

# XAML for the UI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$($CONFIG.OrgName) Gaming Launcher"
        WindowState="Maximized"
        WindowStyle="None"
        Background="$($CONFIG.BackgroundColor)"
        KeyDown="Window_KeyDown">
    
    <Window.Resources>
        <Style x:Key="GameButton" TargetType="Button">
            <Setter Property="Background" Value="$($CONFIG.AccentColor)"/>
            <Setter Property="Foreground" Value="$($CONFIG.TextColor)"/>
            <Setter Property="FontSize" Value="18"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Margin" Value="10"/>
            <Setter Property="Padding" Value="20"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="15"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" 
                                            VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($CONFIG.HighlightColor)"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="100"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="80"/>
        </Grid.RowDefinitions>
        
        <!-- Header -->
        <Border Grid.Row="0" Background="$($CONFIG.AccentColor)" Padding="20">
            <Grid>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="🎮" FontSize="48" Margin="0,0,20,0"/>
                    <StackPanel>
                        <TextBlock Text="$($CONFIG.OrgName)" 
                                 FontSize="32" 
                                 FontWeight="Bold" 
                                 Foreground="$($CONFIG.TextColor)"/>
                        <TextBlock x:Name="WelcomeText" 
                                 Text="Welcome, Player!" 
                                 FontSize="16" 
                                 Foreground="#CCCCCC"/>
                    </StackPanel>
                </StackPanel>
                
                <StackPanel Orientation="Horizontal" 
                          HorizontalAlignment="Right" 
                          VerticalAlignment="Center">
                    <TextBlock x:Name="ClockText" 
                             Text="12:00 PM" 
                             FontSize="24" 
                             Foreground="$($CONFIG.TextColor)" 
                             Margin="0,0,20,0"/>
                    <Button x:Name="LogoutButton" 
                          Content="🚪 Logout" 
                          Style="{StaticResource GameButton}"
                          Background="#DC3545"/>
                </StackPanel>
            </Grid>
        </Border>
        
        <!-- Main Content -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="40">
                <!-- Games Section -->
                <TextBlock Text="🎮 GAMES" 
                         FontSize="28" 
                         FontWeight="Bold" 
                         Foreground="$($CONFIG.TextColor)" 
                         Margin="0,0,0,20"/>
                
                <WrapPanel x:Name="GamesPanel" Margin="0,0,0,40"/>
                
                <!-- Utilities Section -->
                <TextBlock Text="🛠️ UTILITIES" 
                         FontSize="28" 
                         FontWeight="Bold" 
                         Foreground="$($CONFIG.TextColor)" 
                         Margin="0,0,0,20"/>
                
                <WrapPanel x:Name="UtilitiesPanel"/>
            </StackPanel>
        </ScrollViewer>
        
        <!-- Footer -->
        <Border Grid.Row="2" Background="$($CONFIG.AccentColor)" Padding="20">
            <Grid>
                <TextBlock Text="Press ALT+F4 to exit | Press F11 for fullscreen" 
                         FontSize="14" 
                         Foreground="#CCCCCC" 
                         VerticalAlignment="Center"/>
                
                <StackPanel Orientation="Horizontal" 
                          HorizontalAlignment="Right" 
                          VerticalAlignment="Center">
                    <Button x:Name="HelpButton" 
                          Content="❓ Help" 
                          Style="{StaticResource GameButton}"
                          Margin="5"/>
                    <Button x:Name="SettingsButton" 
                          Content="⚙️ Settings" 
                          Style="{StaticResource GameButton}"
                          Margin="5"/>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$gamesPanel = $window.FindName("GamesPanel")
$utilitiesPanel = $window.FindName("UtilitiesPanel")
$welcomeText = $window.FindName("WelcomeText")
$clockText = $window.FindName("ClockText")
$logoutButton = $window.FindName("LogoutButton")
$helpButton = $window.FindName("HelpButton")
$settingsButton = $window.FindName("SettingsButton")

# Set welcome message
$username = $env:USERNAME
$welcomeText.Text = "Welcome, $username!"

# Update clock
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    $clockText.Text = Get-Date -Format "h:mm:ss tt"
})
$timer.Start()

# Function to create game button
function New-GameButton {
    param($game)
    
    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.FindResource("GameButton")
    $button.Width = 250
    $button.Height = 150
    $button.Background = $game.Color
    
    $stack = New-Object System.Windows.Controls.StackPanel
    
    $icon = New-Object System.Windows.Controls.TextBlock
    $icon.Text = $game.Icon
    $icon.FontSize = 48
    $icon.HorizontalAlignment = "Center"
    $icon.Margin = "0,0,0,10"
    
    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $game.Name
    $name.FontSize = 18
    $name.FontWeight = "Bold"
    $name.HorizontalAlignment = "Center"
    
    if ($game.Launcher) {
        $launcher = New-Object System.Windows.Controls.TextBlock
        $launcher.Text = "via $($game.Launcher)"
        $launcher.FontSize = 12
        $launcher.Foreground = "#CCCCCC"
        $launcher.HorizontalAlignment = "Center"
        $launcher.Margin = "0,5,0,0"
        $stack.Children.Add($launcher)
    }
    
    $stack.Children.Add($icon)
    $stack.Children.Add($name)
    
    $button.Content = $stack
    
    $button.Add_Click({
        Start-Application $game
    })
    
    return $button
}

# Function to launch application
function Start-Application {
    param($app)
    
    try {
        if ($app.Action) {
            # Handle special actions
            switch ($app.Action) {
                "audio" {
                    Start-Process "ms-settings:sound"
                }
                "bluetooth" {
                    Start-Process "ms-settings:bluetooth"
                }
            }
        }
        elseif ($app.Path -like "steam://*" -or $app.Path -like "com.epicgames.*") {
            # Handle URL protocols
            Start-Process $app.Path
        }
        else {
            # Launch executable
            if (Test-Path $app.Path) {
                Start-Process $app.Path
            }
            else {
                [System.Windows.MessageBox]::Show(
                    "Application not found: $($app.Name)`n`nPath: $($app.Path)",
                    "Error",
                    "OK",
                    "Error"
                )
            }
        }
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Error launching $($app.Name):`n`n$($_.Exception.Message)",
            "Error",
            "OK",
            "Error"
        )
    }
}

# Populate games
foreach ($game in $GAMES) {
    $button = New-GameButton $game
    $gamesPanel.Children.Add($button)
}

# Populate utilities
foreach ($utility in $UTILITIES) {
    $button = New-GameButton $utility
    $utilitiesPanel.Children.Add($button)
}

# Logout button
$logoutButton.Add_Click({
    $result = [System.Windows.MessageBox]::Show(
        "Are you sure you want to logout?",
        "Confirm Logout",
        "YesNo",
        "Question"
    )
    
    if ($result -eq "Yes") {
        # Logout
        shutdown /l
    }
})

# Help button
$helpButton.Add_Click({
    [System.Windows.MessageBox]::Show(
        "Gaming Launcher Help`n`n" +
        "• Click any game to launch it`n" +
        "• Use utilities for Discord, TeamSpeak, etc.`n" +
        "• Press ALT+F4 to exit launcher`n" +
        "• Press F11 for fullscreen`n" +
        "`nNeed assistance? Contact tournament staff!",
        "Help",
        "OK",
        "Information"
    )
})

# Settings button (admin only)
$settingsButton.Add_Click({
    $password = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter admin password:",
        "Admin Access Required"
    )
    
    if ($password -eq "admin123") {
        # Launch Windows Explorer
        Start-Process "explorer.exe"
    }
    else {
        [System.Windows.MessageBox]::Show(
            "Invalid password",
            "Access Denied",
            "OK",
            "Error"
        )
    }
})

# Handle keyboard shortcuts
$window.Add_KeyDown({
    param($sender, $e)
    
    # F11 for fullscreen toggle
    if ($e.Key -eq "F11") {
        if ($window.WindowState -eq "Maximized") {
            $window.WindowState = "Normal"
            $window.WindowStyle = "SingleBorderWindow"
        }
        else {
            $window.WindowState = "Maximized"
            $window.WindowStyle = "None"
        }
    }
    
    # Ctrl+Alt+Del override (prevent task manager access)
    if ($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control -and
        $e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Alt -and
        $e.Key -eq "Delete") {
        $e.Handled = $true
    }
})

# Show window
$window.ShowDialog() | Out-Null
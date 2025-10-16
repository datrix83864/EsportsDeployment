#!/bin/bash
#
# LANCache Pre-fill Script
# Downloads popular games to pre-populate the cache before an event
#
# Usage:
#   ./prefill.sh --game fortnite
#   ./prefill.sh --all
#   ./prefill.sh --list
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Game definitions with approximate sizes
declare -A GAMES=(
    ["fortnite"]="50GB|Epic Games"
    ["rocket-league"]="20GB|Epic Games"
    ["valorant"]="25GB|Riot Games"
    ["league-of-legends"]="12GB|Riot Games"
    ["overwatch2"]="30GB|Battle.net"
    ["marvel-rivals"]="35GB|Steam"
    ["csgo"]="25GB|Steam"
    ["dota2"]="40GB|Steam"
    ["apex-legends"]="70GB|Origin"
)

show_help() {
    cat << EOF
LANCache Pre-fill Script

Usage:
  $0 --game <game-name>    Pre-fill a specific game
  $0 --all                 Pre-fill all configured games
  $0 --list                List available games
  $0 --help                Show this help

Examples:
  $0 --game fortnite       Download Fortnite to cache
  $0 --all                 Download all games

Available games:
EOF
    
    for game in "${!GAMES[@]}"; do
        IFS='|' read -r size platform <<< "${GAMES[$game]}"
        printf "  %-20s %10s  (%s)\n" "$game" "$size" "$platform"
    done | sort
    
    echo ""
    echo "Note: Pre-filling requires:"
    echo "  - Sufficient disk space"
    echo "  - Good internet connection"
    echo "  - Time (can take hours)"
    echo "  - Game clients installed on a PC"
}

list_games() {
    echo "Available Games for Pre-fill:"
    echo "=============================="
    echo ""
    
    for game in "${!GAMES[@]}"; do
        IFS='|' read -r size platform <<< "${GAMES[$game]}"
        printf "%-20s %10s  Platform: %s\n" "$game" "$size" "$platform"
    done | sort
    
    echo ""
    echo "Total games: ${#GAMES[@]}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if LANCache is running
    if ! docker ps | grep -q lancache; then
        log_error "LANCache containers are not running"
        log_info "Start them with: cd /opt/lancache && docker-compose up -d"
        exit 1
    fi
    
    # Check disk space
    local available=$(df /srv/lancache/data | tail -1 | awk '{print $4}')
    local available_gb=$((available / 1024 / 1024))
    
    if [ $available_gb -lt 100 ]; then
        log_warning "Low disk space: ${available_gb}GB available"
        log_warning "Pre-filling may fail if space runs out"
    else
        log_success "Disk space OK: ${available_gb}GB available"
    fi
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "No internet connectivity"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

prefill_steam_game() {
    local game_name=$1
    local app_id=$2
    
    log_info "Pre-filling Steam game: $game_name (App ID: $app_id)"
    
    # This requires steamcmd
    if ! command -v steamcmd &> /dev/null; then
        log_warning "steamcmd not installed. Skipping $game_name"
        log_info "Install with: apt install steamcmd"
        return 1
    fi
    
    log_info "Downloading $game_name..."
    steamcmd +login anonymous +app_update "$app_id" validate +quit
    
    log_success "$game_name pre-filled"
}

prefill_game() {
    local game=$1
    
    if [[ ! ${GAMES[$game]+_} ]]; then
        log_error "Unknown game: $game"
        log_info "Use --list to see available games"
        return 1
    fi
    
    IFS='|' read -r size platform <<< "${GAMES[$game]}"
    
    log_info "Pre-filling: $game"
    log_info "Platform: $platform"
    log_info "Approximate size: $size"
    
    echo ""
    log_warning "IMPORTANT:"
    echo "  1. This requires the game client to be installed"
    echo "  2. You need to actually download the game"
    echo "  3. LANCache will cache it as you download"
    echo ""
    log_info "Manual steps:"
    
    case $platform in
        "Steam")
            echo "  1. Open Steam on a client PC"
            echo "  2. Make sure DNS is set to LANCache (${LANCACHE_IP:-192.168.1.11})"
            echo "  3. Download/verify $game"
            echo "  4. LANCache will cache it automatically"
            ;;
        "Epic Games")
            echo "  1. Open Epic Games Launcher on a client PC"
            echo "  2. Make sure DNS is set to LANCache (${LANCACHE_IP:-192.168.1.11})"
            echo "  3. Download/verify $game"
            echo "  4. LANCache will cache it automatically"
            ;;
        "Riot Games")
            echo "  1. Open Riot Client on a client PC"
            echo "  2. Make sure DNS is set to LANCache (${LANCACHE_IP:-192.168.1.11})"
            echo "  3. Download/verify $game"
            echo "  4. LANCache will cache it automatically"
            ;;
        "Battle.net")
            echo "  1. Open Battle.net launcher on a client PC"
            echo "  2. Make sure DNS is set to LANCache (${LANCACHE_IP:-192.168.1.11})"
            echo "  3. Download/verify $game"
            echo "  4. LANCache will cache it automatically"
            ;;
    esac
    
    echo ""
    read -p "Press Enter when download is complete..." -r
    
    # Verify cache was populated
    local cache_size=$(du -sh /srv/lancache/data 2>/dev/null | cut -f1)
    log_info "Current cache size: $cache_size"
    log_success "$game pre-fill process complete"
}

prefill_all() {
    log_info "Pre-filling all configured games"
    log_warning "This will take a LONG time and use significant bandwidth"
    
    read -p "Continue? (yes/no): " -r
    if [[ $REPLY != "yes" ]]; then
        log_info "Cancelled"
        exit 0
    fi
    
    for game in "${!GAMES[@]}"; do
        echo ""
        echo "=========================================="
        prefill_game "$game"
        echo "=========================================="
        echo ""
    done
    
    log_success "All games pre-filled!"
    
    # Show final cache stats
    echo ""
    echo "Final Cache Statistics:"
    du -sh /srv/lancache/data
    echo ""
    echo "Top 10 Cached Items:"
    du -sh /srv/lancache/data/* 2>/dev/null | sort -hr | head -10
}

monitor_prefill() {
    log_info "Monitoring cache growth..."
    log_info "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        clear
        echo "LANCache Pre-fill Monitor"
        echo "========================="
        echo ""
        echo "Cache Size:"
        du -sh /srv/lancache/data 2>/dev/null || echo "Calculating..."
        echo ""
        echo "Recent Activity:"
        docker logs lancache --tail 20 2>/dev/null | grep -E "(HIT|MISS|UPDATING)"
        echo ""
        echo "Active Downloads:"
        ss -tn | grep :80 | wc -l
        sleep 5
    done
}

# Parse arguments
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --list|-l)
        list_games
        exit 0
        ;;
    --game|-g)
        if [ -z "${2:-}" ]; then
            log_error "Game name required"
            echo "Usage: $0 --game <game-name>"
            exit 1
        fi
        check_prerequisites
        prefill_game "$2"
        ;;
    --all|-a)
        check_prerequisites
        prefill_all
        ;;
    --monitor|-m)
        monitor_prefill
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac

exit 0
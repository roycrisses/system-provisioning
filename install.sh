#!/bin/bash

# Dotfiles Installation Script
# This script is idempotent and can be run multiple times safely.

set -e # Exit on error

# --- Variables ---
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
PACKAGES=(zsh git nvim tmux)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Functions ---

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check for Git
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed. Please install Git first."
        exit 1
    fi

    # Check for Stow
    if ! command -v stow &> /dev/null; then
        log_info "GNU Stow not found. Attempting to install..."
        install_package stow
    else
        log_success "GNU Stow is installed."
    fi
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

install_package() {
    PACKAGE=$1
    OS=$(detect_os)

    if [ "$OS" == "macos" ]; then
        if ! command -v brew &> /dev/null; then
             log_error "Homebrew not found. Please install Homebrew first."
             exit 1
        fi
        brew install "$PACKAGE"
    elif [ "$OS" == "linux" ]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y "$PACKAGE"
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm "$PACKAGE"
        else
            log_error "Unsupported package manager. Please install $PACKAGE manually."
            exit 1
        fi
    fi
}

backup_files() {
    log_info "Checking for conflicting files..."
    local found_conflict=false

    # Simple logic: validation is hard with stow safely without runnning it.
    # We will trust Stow's conflict detection or move known specific files if they are not symlinks.
    # A robust way is to try stow, catch error, and if error, backup.
    
    # For this script, we'll prescan common targets.
    FILES_TO_CHECK=(".zshrc" ".gitconfig" ".tmux.conf" ".config/nvim/init.lua")
    
    for file in "${FILES_TO_CHECK[@]}"; do
        TARGET="$HOME/$file"
        if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
            log_info "Found existing file $TARGET (not a symlink). Backing up..."
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            mv "$TARGET" "$BACKUP_DIR/$file"
            found_conflict=true
        fi
    done

    if [ "$found_conflict" = true ]; then
        log_success "Backup completed at $BACKUP_DIR"
    else
        log_info "No conflicts found."
    fi
}

run_stow() {
    log_info "Stowing packages..."
    # Ensure we are in the dotfiles directory
    cd "$(dirname "$0")" || exit

    for pkg in "${PACKAGES[@]}"; do
        # -v: verbose, -R: restow (prune/delete old, stow new)
        stow -v -R -t "$HOME" "$pkg"
    done
    log_success "Dotfiles stowed successfully!"
}

post_install() {
    log_info "Running post-install setup..."
    
    # Install Oh My Zsh if not present
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        # Remove the .zshrc created by OMZ so Stow can link ours
        rm -f "$HOME/.zshrc"
        # Re-run stow for zsh just in case
        stow -v -R -t "$HOME" zsh
    fi

    # Example: Install Tmux Plugin Manager
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        log_info "Installing Tmux Plugin Manager..."
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    fi

    log_success "Post-install setup complete."
}

# --- Main ---
log_info "Starting Dotfiles Installation..."
check_dependencies
backup_files
run_stow
post_install

log_success "Installation Complete! Please restart your shell."

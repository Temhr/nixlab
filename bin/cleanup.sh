#!/bin/bash

# Cleanup script for self-referencing symlinks
# This script will fix the current broken state

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Define folders to check
DEFAULT_FOLDERS=(
    ".cache"
    ".local"
    "Desktop"
    "Documents"
    "Downloads"
    "Music"
    "Pictures"
    "Videos"
    "Public"
    "Templates"
)

SHELF_DIR="$HOME/shelf/default"

print_status "Cleaning up self-referencing symlinks..."

# Step 1: Remove bad symlinks inside shelf/default directories
print_status "Step 1: Removing bad symlinks inside ~/shelf/default/ directories..."
for folder in "${DEFAULT_FOLDERS[@]}"; do
    shelf_folder="$SHELF_DIR/$folder"
    if [[ -d "$shelf_folder" ]]; then
        # Check for symlinks inside this directory that point to themselves
        if find "$shelf_folder" -maxdepth 1 -name "$folder" -type l 2>/dev/null | grep -q .; then
            print_warning "Found self-referencing symlink in $shelf_folder"
            # Remove the bad symlink
            rm -f "$shelf_folder/$folder"
            print_success "Removed bad symlink: $shelf_folder/$folder"
        fi
    fi
done

# Step 2: Check home directory for proper symlinks
print_status "Step 2: Checking home directory symlinks..."
for folder in "${DEFAULT_FOLDERS[@]}"; do
    home_path="$HOME/$folder"
    shelf_path="$SHELF_DIR/$folder"

    if [[ -L "$home_path" ]]; then
        # Check if it's a valid symlink
        target=$(readlink "$home_path")
        if [[ "$target" == "$home_path" ]] || [[ "$target" == "$folder" ]] || [[ "$target" == "./$folder" ]]; then
            print_warning "Found self-referencing symlink at $home_path"
            rm "$home_path"
            print_success "Removed bad symlink: $home_path"
        elif [[ -d "$shelf_path" ]]; then
            # Check if symlink points to the right place
            if [[ "$target" == "$shelf_path" ]] || [[ "$target" == "shelf/default/$folder" ]]; then
                print_success "Good symlink found: $home_path -> $target"
            else
                print_warning "Symlink points to wrong location: $home_path -> $target"
                print_status "Fixing symlink..."
                rm "$home_path"
                ln -s "shelf/default/$folder" "$home_path"
                print_success "Fixed symlink: $home_path -> shelf/default/$folder"
            fi
        fi
    elif [[ -d "$shelf_path" && ! -e "$home_path" ]]; then
        # Folder exists in shelf but no symlink in home - create it
        print_status "Creating missing symlink for $folder"
        ln -s "shelf/default/$folder" "$home_path"
        print_success "Created symlink: $home_path -> shelf/default/$folder"
    fi
done

# Step 3: Verify everything is working
print_status "Step 3: Verifying all symlinks..."
all_good=true
for folder in "${DEFAULT_FOLDERS[@]}"; do
    home_path="$HOME/$folder"
    shelf_path="$SHELF_DIR/$folder"

    if [[ -d "$shelf_path" ]]; then
        if [[ -L "$home_path" && -d "$home_path" ]]; then
            target=$(readlink "$home_path")
            print_success "✓ $folder: $home_path -> $target"
        else
            print_error "✗ $folder: Missing or broken symlink"
            all_good=false
        fi
    fi
done

if [[ "$all_good" == "true" ]]; then
    print_success "All symlinks are working correctly!"
else
    print_warning "Some issues remain. You may need to run the organizer script again."
fi

print_status "Cleanup complete!"

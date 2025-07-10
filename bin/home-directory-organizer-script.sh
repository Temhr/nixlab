#!/bin/bash

# Home Directory Organizer Script
# Moves default home directories to ~/shelf/ and creates symlinks

# Define default folders to move
DEFAULT_FOLDERS=(
    "Desktop"
    "Documents"
    "Downloads"
    "Music"
    "Pictures"
    "Videos"
    "Public"
    "Templates"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if a directory exists and is accessible
check_directory() {
    local dir="$1"
    if [[ -d "$dir" && -r "$dir" && -w "$dir" ]]; then
        return 0
    else
        return 1
    fi
}

# Step 1: Check if there are default folders in the home directory
print_status "Step 1: Checking for default folders in home directory..."
found_folders=()
for folder in "${DEFAULT_FOLDERS[@]}"; do
    if [[ -d "$HOME/$folder" ]]; then
        found_folders+=("$folder")
        print_status "Found: $HOME/$folder"
    fi
done

if [[ ${#found_folders[@]} -eq 0 ]]; then
    print_warning "No default folders found in home directory. Nothing to do."
    exit 0
fi

print_success "Found ${#found_folders[@]} default folder(s) in home directory."

# Step 2: Check if ~/shelf/default/ directory exists and is accessible
print_status "Step 2: Checking ~/shelf/default/ directory..."
SHELF_DIR="$HOME/shelf/default"

if [[ ! -d "$SHELF_DIR" ]]; then
    print_status "Creating ~/shelf/default/ directory..."
    if mkdir -p "$SHELF_DIR"; then
        print_success "Created ~/shelf/default/ directory."
    else
        print_error "Failed to create ~/shelf/default/ directory."
        exit 1
    fi
fi

if ! check_directory "$SHELF_DIR"; then
    print_error "~/shelf/default/ directory is not accessible (check permissions)."
    exit 1
fi

print_success "~/shelf/default/ directory is accessible."

# Step 3: Check if there are default folders in ~/shelf/default/ directory
print_status "Step 3: Checking for existing default folders in ~/shelf/default/..."
existing_in_shelf=()
for folder in "${found_folders[@]}"; do
    if [[ -e "$SHELF_DIR/$folder" ]]; then
        existing_in_shelf+=("$folder")
        print_warning "Found existing: $SHELF_DIR/$folder"
    fi
done

if [[ ${#existing_in_shelf[@]} -gt 0 ]]; then
    print_error "Found ${#existing_in_shelf[@]} folder(s) already in ~/shelf/default/:"
    for folder in "${existing_in_shelf[@]}"; do
        print_error "  - $folder"
    done
    print_error "Please resolve conflicts before running this script."
    exit 1
fi

print_success "No conflicting folders found in ~/shelf/default/."

# Step 4 & 5: Move folders and create symlinks
print_status "Step 4 & 5: Moving folders and creating symlinks..."

# Ask for confirmation
echo
print_warning "About to move the following folders to ~/shelf/default/ and create symlinks:"
for folder in "${found_folders[@]}"; do
    echo "  $HOME/$folder -> $SHELF_DIR/$folder"
done

# Perform the moves and symlink creation
moved_folders=()
failed_folders=()

for folder in "${found_folders[@]}"; do
    src_path="$HOME/$folder"
    dest_path="$SHELF_DIR/$folder"

    print_status "Processing $folder..."

    # Move the folder
    if mv "$src_path" "$dest_path"; then
        print_success "Moved $folder to ~/shelf/default/"

        # Create symlink
        if ln -s "$dest_path" "$src_path"; then
            print_success "Created symlink for $folder"
            moved_folders+=("$folder")
        else
            print_error "Failed to create symlink for $folder"
            # Try to move back
            if mv "$dest_path" "$src_path"; then
                print_warning "Restored $folder to original location"
            else
                print_error "CRITICAL: Failed to restore $folder! Manual intervention required."
            fi
            failed_folders+=("$folder")
        fi
    else
        print_error "Failed to move $folder"
        failed_folders+=("$folder")
    fi
done

# Summary
echo
print_status "=== SUMMARY ==="
if [[ ${#moved_folders[@]} -gt 0 ]]; then
    print_success "Successfully processed ${#moved_folders[@]} folder(s):"
    for folder in "${moved_folders[@]}"; do
        print_success "  ✓ $folder"
    done
fi

if [[ ${#failed_folders[@]} -gt 0 ]]; then
    print_error "Failed to process ${#failed_folders[@]} folder(s):"
    for folder in "${failed_folders[@]}"; do
        print_error "  ✗ $folder"
    done
    exit 1
fi

print_success "All operations completed successfully!"
print_status "Your default folders are now organized in ~/shelf/default/ with symlinks in place."

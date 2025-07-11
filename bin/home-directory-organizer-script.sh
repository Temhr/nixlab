#!/bin/bash

# Home Directory Organizer Script - Fixed Version
# Moves default home directories to ~/shelf/default/ and creates symlinks

# Set up logging
LOG_FILE="$HOME/home_organizer.log"
exec 3>&1 4>&2 1>>"$LOG_FILE" 2>&1

# Define default folders to move
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" >&3
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&3
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&3
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&3
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
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

# Function to verify symlink is correct
verify_symlink() {
    local link_path="$1"
    local expected_target="$2"

    if [[ -L "$link_path" ]]; then
        local actual_target=$(readlink "$link_path")
        if [[ "$actual_target" == "$expected_target" ]]; then
            return 0
        else
            print_error "Symlink points to wrong target: $actual_target (expected: $expected_target)"
            return 1
        fi
    else
        print_error "Symlink was not created at $link_path"
        return 1
    fi
}

# Function to safely create symlink
create_safe_symlink() {
    local src_path="$1"
    local dest_path="$2"
    local folder="$3"

    # Use relative path for symlink to avoid issues
    local relative_target="shelf/default/$folder"

    # Remove any existing symlink or file at source location
    if [[ -L "$src_path" ]]; then
        print_status "Removing existing symlink at $src_path"
        rm "$src_path"
    elif [[ -e "$src_path" ]]; then
        print_error "Unexpected file/directory still exists at $src_path"
        return 1
    fi

    # Create the symlink
    print_status "Creating symlink: $src_path -> $relative_target"
    if ln -s "$relative_target" "$src_path"; then
        # Verify the symlink works
        if [[ -d "$src_path" ]] && verify_symlink "$src_path" "$relative_target"; then
            print_success "Symlink created and verified for $folder"
            return 0
        else
            print_error "Symlink verification failed for $folder"
            rm -f "$src_path"
            return 1
        fi
    else
        print_error "Failed to create symlink for $folder"
        return 1
    fi
}

# Step 1: Check if there are default folders in the home directory
print_status "Step 1: Checking for default folders in home directory..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Home Directory Organizer Script"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file: $LOG_FILE"

# First, check for and clean up any existing bad symlinks
print_status "Checking for existing problematic symlinks..."
for folder in "${DEFAULT_FOLDERS[@]}"; do
    src_path="$HOME/$folder"
    if [[ -L "$src_path" ]]; then
        target=$(readlink "$src_path")
        # Check if it's a self-referencing symlink
        if [[ "$target" == "$src_path" ]] || [[ "$target" == "$folder" ]] || [[ "$target" == "./$folder" ]]; then
            print_warning "Found self-referencing symlink: $src_path -> $target"
            print_status "Removing bad symlink: $src_path"
            rm "$src_path"
        fi
    fi
done

found_folders=()
for folder in "${DEFAULT_FOLDERS[@]}"; do
    src_path="$HOME/$folder"
    if [[ -d "$src_path" && ! -L "$src_path" ]]; then
        found_folders+=("$folder")
        print_status "Found: $src_path"
    elif [[ -L "$src_path" ]]; then
        print_status "Symlink already exists: $src_path -> $(readlink "$src_path")"
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
skipped_folders=()

for folder in "${found_folders[@]}"; do
    if [[ -e "$SHELF_DIR/$folder" ]]; then
        existing_in_shelf+=("$folder")
        skipped_folders+=("$folder")
        print_warning "Found existing: $SHELF_DIR/$folder"
    fi
done

if [[ ${#existing_in_shelf[@]} -gt 0 ]]; then
    print_warning "Found ${#existing_in_shelf[@]} folder(s) already in ~/shelf/default/:"
    for folder in "${existing_in_shelf[@]}"; do
        print_warning "  - $folder (will be skipped)"
    done
fi

# Filter out folders that already exist in shelf
folders_to_process=()
for folder in "${found_folders[@]}"; do
    if [[ ! " ${existing_in_shelf[@]} " =~ " ${folder} " ]]; then
        folders_to_process+=("$folder")
    fi
done

if [[ ${#folders_to_process[@]} -eq 0 ]]; then
    print_warning "No folders to process (all already exist in ~/shelf/default/)."
    exit 0
fi

print_success "Ready to proceed with ${#folders_to_process[@]} folder(s)."

# Step 4 & 5: Move folders and create symlinks
print_status "Step 4 & 5: Moving folders and creating symlinks..."

# Show what will be processed
echo >&3
print_warning "About to move the following folders to ~/shelf/default/ and create symlinks:"
for folder in "${folders_to_process[@]}"; do
    echo "  $HOME/$folder -> $SHELF_DIR/$folder" >&3
done

# Perform the moves and symlink creation
moved_folders=()
failed_folders=()

for folder in "${folders_to_process[@]}"; do
    src_path="$HOME/$folder"
    dest_path="$SHELF_DIR/$folder"

    print_status "Processing $folder..."

    # Special handling for system directories that might be in use
    if [[ "$folder" == ".cache" || "$folder" == ".local" ]]; then
        print_warning "System directory $folder detected - using careful copy method"

        # Create destination directory
        if ! mkdir -p "$dest_path"; then
            print_error "Failed to create destination directory: $dest_path"
            failed_folders+=("$folder")
            continue
        fi

        # Copy with rsync if available, otherwise use cp
        copy_success=false
        if command -v rsync >/dev/null 2>&1; then
            print_status "Using rsync for robust copying..."
            if rsync -av --ignore-errors "$src_path/" "$dest_path/"; then
                copy_success=true
                print_success "Successfully copied $folder with rsync"
            else
                print_warning "rsync had some errors, checking if copy was successful..."
                if [[ -d "$dest_path" && $(ls -A "$dest_path" 2>/dev/null) ]]; then
                    copy_success=true
                    print_success "Copy appears successful despite rsync warnings"
                fi
            fi
        else
            print_status "Using cp for copying..."
            if cp -a "$src_path/." "$dest_path/"; then
                copy_success=true
                print_success "Successfully copied $folder with cp"
            fi
        fi

        if [[ "$copy_success" == "true" ]]; then
            # Create backup of original
            backup_name="${src_path}.backup_$(date +%s)"
            if mv "$src_path" "$backup_name"; then
                print_status "Created backup: $backup_name"

                # Create symlink
                if create_safe_symlink "$src_path" "$dest_path" "$folder"; then
                    # Remove backup after successful symlink
                    if rm -rf "$backup_name"; then
                        print_success "Removed backup after successful symlink creation"
                    else
                        print_warning "Symlink successful but backup remains at $backup_name"
                    fi
                    moved_folders+=("$folder")
                else
                    print_error "Failed to create symlink for $folder"
                    # Restore from backup
                    if mv "$backup_name" "$src_path"; then
                        print_status "Restored original directory from backup"
                    else
                        print_error "CRITICAL: Failed to restore $folder from backup!"
                    fi
                    rm -rf "$dest_path"
                    failed_folders+=("$folder")
                fi
            else
                print_error "Failed to create backup of $folder"
                rm -rf "$dest_path"
                failed_folders+=("$folder")
            fi
        else
            print_error "Failed to copy $folder"
            rm -rf "$dest_path"
            failed_folders+=("$folder")
        fi
    else
        # Standard move for regular directories
        print_status "Moving regular directory $folder"
        if mv "$src_path" "$dest_path"; then
            print_success "Moved $folder to ~/shelf/default/"

            # Create symlink
            if create_safe_symlink "$src_path" "$dest_path" "$folder"; then
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
    fi
done

# Summary
echo >&3
print_status "=== SUMMARY ==="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script completed"

if [[ ${#moved_folders[@]} -gt 0 ]]; then
    print_success "Successfully processed ${#moved_folders[@]} folder(s):"
    for folder in "${moved_folders[@]}"; do
        print_success "  ✓ $folder"
    done
fi

if [[ ${#skipped_folders[@]} -gt 0 ]]; then
    print_warning "Skipped ${#skipped_folders[@]} folder(s) (already existed in destination):"
    for folder in "${skipped_folders[@]}"; do
        print_warning "  ~ $folder"
    done
fi

if [[ ${#failed_folders[@]} -gt 0 ]]; then
    print_error "Failed to process ${#failed_folders[@]} folder(s):"
    for folder in "${failed_folders[@]}"; do
        print_error "  ✗ $folder"
    done
fi

# Show log file location
echo >&3
echo -e "${BLUE}[INFO]${NC} Detailed log saved to: $LOG_FILE" >&3

# Final verification of symlinks
if [[ ${#moved_folders[@]} -gt 0 ]]; then
    echo >&3
    print_status "Verifying symlinks..."
    for folder in "${moved_folders[@]}"; do
        src_path="$HOME/$folder"
        if [[ -L "$src_path" ]] && [[ -d "$src_path" ]]; then
            target=$(readlink "$src_path")
            print_success "✓ $folder -> $target"
        else
            print_error "✗ $folder symlink verification failed"
        fi
    done
fi

# Determine exit code based on results
if [[ ${#moved_folders[@]} -gt 0 ]]; then
    print_success "Operation completed! Some folders were successfully processed."
    if [[ ${#failed_folders[@]} -gt 0 ]]; then
        print_status "Note: Some folders failed to process, but the script continued."
        exit 2  # Partial success
    else
        print_success "All processable folders completed successfully!"
        exit 0  # Full success
    fi
else
    if [[ ${#skipped_folders[@]} -gt 0 ]]; then
        print_warning "No folders were processed (all were skipped)."
        exit 0
    else
        print_error "No folders were successfully processed."
        exit 1  # Failure
    fi
fi

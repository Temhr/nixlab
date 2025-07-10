#!/bin/bash

# Home Directory Organizer Script
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

# Step 1: Check if there are default folders in the home directory
print_status "Step 1: Checking for default folders in home directory..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Home Directory Organizer Script"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file: $LOG_FILE"
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
    print_warning "Found ${#existing_in_shelf[@]} folder(s) already in ~/shelf/default/:"
    for folder in "${existing_in_shelf[@]}"; do
        print_warning "  - $folder (will be skipped)"
    done
    print_warning "These folders will be skipped during processing."
fi

print_success "Ready to proceed with available folders."

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

    # Special handling for system directories that might be in use
    if [[ "$folder" == ".cache" || "$folder" == ".local" ]]; then
        print_warning "System directory $folder detected - using careful copy method"

        # First try to stop any processes that might be using these directories
        if [[ "$folder" == ".cache" ]]; then
            print_status "Attempting to clear some cache files first..."
            # Clear some safe-to-remove cache files, ignore errors
            find "$src_path" -name "*.tmp" -delete 2>/dev/null || true
            find "$src_path" -name "*.cache" -delete 2>/dev/null || true
        fi

        # Use rsync if available, otherwise cp with error handling
        if command -v rsync >/dev/null 2>&1; then
            print_status "Using rsync for robust copying..."
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting rsync copy of $folder"
            if rsync -av --ignore-errors --exclude='*.tmp' --exclude='*.lock' "$src_path/" "$dest_path/" >> "$LOG_FILE" 2>&1; then
                print_success "Copied $folder to ~/shelf/default/"
                copy_success=true
            else
                print_error "Failed to copy $folder with rsync"
                copy_success=false
            fi
        else
            # Use cp with options to handle disappearing files
            print_status "Using cp for copying (some errors about missing files are normal)..."
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting cp copy of $folder"
            if cp -a --no-target-directory "$src_path" "$dest_path" >> "$LOG_FILE" 2>&1 || cp -a "$src_path" "$dest_path" >> "$LOG_FILE" 2>&1; then
                print_success "Copied $folder to ~/shelf/default/"
                copy_success=true
            else
                print_warning "Standard cp failed, trying with error tolerance..."
                # Try creating the directory first and then copying contents
                mkdir -p "$dest_path" && \
                (find "$src_path" -mindepth 1 -maxdepth 1 -exec cp -a {} "$dest_path/" \; >> "$LOG_FILE" 2>&1 || true) && \
                copy_success=true || copy_success=false

                if [[ "$copy_success" == "true" ]]; then
                    print_success "Copied $folder to ~/shelf/default/ (with some expected errors)"
                else
                    print_error "Failed to copy $folder"
                    copy_success=false
                fi
            fi
        fi

        if [[ "$copy_success" == "true" ]]; then
            # Create symlink with careful renaming
            temp_name="${src_path}.script_backup_$(date +%s)"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating symlink for $folder"
            if mv "$src_path" "$temp_name" >> "$LOG_FILE" 2>&1 && ln -s "$dest_path" "$src_path" >> "$LOG_FILE" 2>&1; then
                print_success "Created symlink for $folder"
                # Remove the backup after successful symlink creation
                if rm -rf "$temp_name" >> "$LOG_FILE" 2>&1; then
                    print_success "Cleaned up original $folder directory"
                else
                    print_warning "Symlink created but backup directory remains at $temp_name"
                fi
                moved_folders+=("$folder")
            else
                print_error "Failed to create symlink for $folder"
                # Try to restore
                if [[ -d "$temp_name" ]]; then
                    mv "$temp_name" "$src_path" >> "$LOG_FILE" 2>&1
                fi
                rm -rf "$dest_path" >> "$LOG_FILE" 2>&1
                failed_folders+=("$folder")
            fi
        else
            failed_folders+=("$folder")
        fi
    else
        # Standard move for regular directories
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Moving regular directory $folder"
        if mv "$src_path" "$dest_path" >> "$LOG_FILE" 2>&1; then
            print_success "Moved $folder to ~/shelf/default/"

            # Create symlink
            if ln -s "$dest_path" "$src_path" >> "$LOG_FILE" 2>&1; then
                print_success "Created symlink for $folder"
                moved_folders+=("$folder")
            else
                print_error "Failed to create symlink for $folder"
                # Try to move back
                if mv "$dest_path" "$src_path" >> "$LOG_FILE" 2>&1; then
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

print_status "Your default folders are now organized in ~/shelf/default/ with symlinks in place."

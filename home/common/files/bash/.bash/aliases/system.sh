# aliases/system.sh — system monitoring, hardware info, and safety guards

# Process monitoring
alias psu='ps auxf'
alias topc='htop'
alias load='uptime'
alias watchps='watch "ps aux --sort=-%mem | head -n 10"'

# Top memory consumers (by process name / full exe path)
alias memp5='ps -eo pid,ppid,%cpu,comm --sort=-%mem | head -n6'
alias memp10='ps -eo pid,ppid,%cpu,comm --sort=-%mem | head -n11'
alias mem5='ps -eo pid,user,ppid,%mem,%cpu,exe --sort=-%mem | head -n6'
alias mem10='ps -eo pid,user,ppid,%mem,%cpu,exe --sort=-%mem | head -n11'

# Top CPU consumers (by process name / full exe path)
alias cpup5='ps -eo pid,ppid,%cpu,comm --sort=-%cpu | head -n6'
alias cpup10='ps -eo pid,ppid,%cpu,comm --sort=-%cpu | head -n11'
alias cpu5='ps -eo pid,user,ppid,%mem,%cpu,exe --sort=-%cpu | head -n6'
alias cpu10='ps -eo pid,user,ppid,%mem,%cpu,exe --sort=-%cpu | head -n11'

# Memory and disk
alias mem='free -h'
alias df='df -h -x squashfs -x tmpfs -x devtmpfs'
alias diskuse='du -h --max-depth=1'
alias duh='du -sh *'

# Largest directories in cwd
alias dir5='du -cksh * | sort -hr | head -n 5'
alias dir10='du -cksh * | sort -hr | head -n 10'

# Hardware and kernel info
alias arch='uname -m'
alias kernel='uname -r'
alias uptime='uptime -p'
alias cpu='lscpu'
alias drives='lsblk -f'
alias pci='lspci'
alias usb='lsusb'
alias os='cat /etc/os-release'
alias mountlist='mount | column -t'   # formatted mount table

# GPU info
alias vdr='lspci -n -n -k | grep -A 2 -e VGA -e 3D'   # active video drivers
alias lsgpu='lspci | grep -i -E "vga|3d|display"'      # available GPUs
alias nsmi='watch -n1 nvidia-smi'                       # live nvidia stats

# Logs and services
alias journal='journalctl -b -p err'  # errors since last boot
alias logs='journalctl -xe'           # full journal with context
alias jctl='journalctl -u'            # follow a specific unit: jctl <name>
alias sctl='systemctl'

# Cache / temp cleanup
alias flushmem='sync; echo 3 | sudo tee /proc/sys/vm/drop_caches'
alias rmcache='rm -rf ~/.cache/*'

# Safety guards
alias :q='echo "Wrong shell, friend 😄"'
alias format='echo "Nope 😅"'

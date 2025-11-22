#!/usr/bin/env bash
# maintenance-logger.sh
# Helper script to log manual maintenance tasks to Loki via Promtail

set -euo pipefail

# Configuration
LOG_FILE="/var/log/maintenance.log"
CHECKLIST_SECTIONS=(
  "I.1:Hardware Health"
  "I.2:Storage Capacity"
  "I.3:Network Hardware"
  "II.4:OS Updates"
  "II.5:System Logs"
  "II.6:Resource Utilization"
  "III.7:Backup Status"
  "III.8:Filesystem Health"
  "III.9:Snapshot Management"
  "IV.10:Firewall & Access Control"
  "IV.11:Authentication & Identity"
  "IV.12:Network Connectivity"
  "IV.13:Certificate Management"
  "V.14:Service Availability"
  "V.15:Database Maintenance"
  "V.16:Web Services"
  "V.17:Message Queues"
  "VI.18:Container Infrastructure"
  "VI.19:VM Maintenance"
  "VI.20:Orchestration"
  "VII.21:Metrics Coverage"
  "VII.22:Alerting"
  "VII.23:Log Management"
  "VIII.24:Configuration Drift"
  "VIII.25:Documentation"
  "VIII.26:Compliance & Policy"
  "IX.27:Redundancy Systems"
  "IX.28:Disaster Recovery"
  "X.29:Weekly Tasks"
  "X.30:Monthly Tasks"
  "X.31:Quarterly Tasks"
)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Functions
log_maintenance() {
  local section="$1"
  local task="$2"
  local status="$3"
  local notes="${4:-}"

  local timestamp=$(date -Iseconds)
  local hostname=$(hostname)
  local user=$(whoami)

  # JSON format for Loki
  local json_log=$(cat <<EOF
{"timestamp":"$timestamp","level":"info","section":"$section","task":"$task","status":"$status","notes":"$notes","hostname":"$hostname","user":"$user"}
EOF
)

  echo "$json_log" >> "$LOG_FILE"
  echo -e "${GREEN}✓${NC} Logged: $section - $task [$status]"
}

show_menu() {
  echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}    Server Maintenance Task Logger${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════${NC}\n"

  echo "Select maintenance section:"
  for i in "${!CHECKLIST_SECTIONS[@]}"; do
    IFS=':' read -r code name <<< "${CHECKLIST_SECTIONS[$i]}"
    printf "%2d) %-8s %s\n" "$((i+1))" "$code" "$name"
  done

  echo ""
  echo " q) Quick log entry"
  echo " v) View recent logs"
  echo " s) Show completion stats"
  echo " x) Exit"
  echo ""
}

quick_log() {
  echo -e "\n${YELLOW}Quick Log Entry${NC}"
  read -p "Task description: " task
  read -p "Status (completed/skipped/failed): " status
  read -p "Notes (optional): " notes

  log_maintenance "QUICK" "$task" "$status" "$notes"
}

view_recent() {
  echo -e "\n${BLUE}Recent Maintenance Logs (last 20)${NC}"
  echo "════════════════════════════════════════════════════"

  if [[ -f "$LOG_FILE" ]]; then
    tail -n 20 "$LOG_FILE" | while read -r line; do
      local timestamp=$(echo "$line" | jq -r '.timestamp' 2>/dev/null || echo "N/A")
      local section=$(echo "$line" | jq -r '.section' 2>/dev/null || echo "N/A")
      local task=$(echo "$line" | jq -r '.task' 2>/dev/null || echo "N/A")
      local status=$(echo "$line" | jq -r '.status' 2>/dev/null || echo "N/A")

      case "$status" in
        completed) color=$GREEN ;;
        failed) color=$RED ;;
        skipped) color=$YELLOW ;;
        *) color=$NC ;;
      esac

      echo -e "${color}[$timestamp]${NC} $section: $task [$status]"
    done
  else
    echo "No logs found."
  fi
}

show_stats() {
  echo -e "\n${BLUE}Maintenance Completion Statistics${NC}"
  echo "════════════════════════════════════════════════════"

  if [[ ! -f "$LOG_FILE" ]]; then
    echo "No logs found."
    return
  fi

  echo -e "\n${YELLOW}Tasks by Status (Last 30 Days):${NC}"
  local cutoff=$(date -d '30 days ago' -Iseconds 2>/dev/null || date -v-30d -Iseconds)

  if [[ -s "$LOG_FILE" ]]; then
    grep '"status"' "$LOG_FILE" 2>/dev/null | \
      cut -d'"' -f4 | \
      sort | uniq -c | sort -rn || echo "  No data available"
  fi

  echo -e "\n${YELLOW}Tasks by Section (Last 30 Days):${NC}"
  if [[ -s "$LOG_FILE" ]]; then
    grep '"section"' "$LOG_FILE" 2>/dev/null | \
      cut -d'"' -f4 | \
      sort | uniq -c | sort -rn | head -10 || echo "  No data available"
  fi

  echo -e "\n${YELLOW}Last Completion Dates by Section:${NC}"
  for section in "${CHECKLIST_SECTIONS[@]}"; do
    IFS=':' read -r code name <<< "$section"
    last_date=$(grep "\"section\":\"$code\"" "$LOG_FILE" 2>/dev/null | \
                tail -1 | jq -r '.timestamp' 2>/dev/null | cut -d'T' -f1)
    if [[ -n "$last_date" && "$last_date" != "null" ]]; then
      echo "  $code: $last_date"
    fi
  done
}

log_section_task() {
  local section_index="$1"

  IFS=':' read -r section_code section_name <<< "${CHECKLIST_SECTIONS[$section_index]}"

  echo -e "\n${BLUE}Section: $section_code - $section_name${NC}"
  echo "────────────────────────────────────────────────────"

  # Show common tasks for this section
  case "$section_code" in
    "I.1")
      echo "Common tasks: CPU temp check, fan inspection, RAM test"
      ;;
    "I.2")
      echo "Common tasks: Check disk space, verify inode usage"
      ;;
    "III.7")
      echo "Common tasks: Verify backup success, check offsite sync, restore test"
      ;;
    "III.8")
      echo "Common tasks: Run ZFS scrub, Btrfs balance, filesystem check"
      ;;
    "IV.13")
      echo "Common tasks: Check cert expiry, verify ACME renewals"
      ;;
    "X.30")
      echo "Common tasks: OS updates, ZFS scrub, backup restore test"
      ;;
  esac

  echo ""
  read -p "Task performed: " task

  echo ""
  echo "Status:"
  echo "  1) completed"
  echo "  2) skipped"
  echo "  3) failed"
  read -p "Select (1-3): " status_choice

  case "$status_choice" in
    1) status="completed" ;;
    2) status="skipped" ;;
    3) status="failed" ;;
    *) status="unknown" ;;
  esac

  read -p "Notes (optional): " notes

  log_maintenance "$section_code" "$task" "$status" "$notes"
}

# Main loop
main() {
  # Ensure log file exists
  if [[ ! -f "$LOG_FILE" ]]; then
    if [[ -w "$(dirname "$LOG_FILE")" ]]; then
      touch "$LOG_FILE"
      chmod 666 "$LOG_FILE"
    else
      echo -e "${RED}Error: Cannot create log file at $LOG_FILE${NC}"
      echo "Run with sudo or check permissions"
      exit 1
    fi
  fi

  while true; do
    show_menu
    read -p "Select option: " choice

    case "$choice" in
      q|Q)
        quick_log
        ;;
      v|V)
        view_recent
        read -p "Press Enter to continue..."
        ;;
      s|S)
        show_stats
        read -p "Press Enter to continue..."
        ;;
      x|X)
        echo -e "\n${GREEN}Goodbye!${NC}\n"
        exit 0
        ;;
      [0-9]*)
        if [[ $choice -ge 1 && $choice -le ${#CHECKLIST_SECTIONS[@]} ]]; then
          log_section_task $((choice - 1))
        else
          echo -e "${RED}Invalid selection${NC}"
          sleep 1
        fi
        ;;
      *)
        echo -e "${RED}Invalid option${NC}"
        sleep 1
        ;;
    esac
  done
}

# Check dependencies
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required but not installed.${NC}"
  echo "Install with: nix-env -iA nixpkgs.jq"
  echo "Or ensure jq is in your system packages"
  exit 1
fi

main

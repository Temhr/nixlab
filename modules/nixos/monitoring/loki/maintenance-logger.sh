#!/usr/bin/env bash
# maintenance-logger.sh
# Helper script to log manual maintenance tasks to Loki

set -euo pipefail

# Configuration
LOG_FILE="${MAINTENANCE_LOG:-/var/log/maintenance.log}"
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
  local section="$1" task="$2" status="$3" notes="${4:-}"
  local timestamp hostname user json_log
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  hostname=$(uname -n)
  user=$(whoami)

  json_log=$(jq -cn \
    --arg timestamp "$timestamp" --arg level "info" \
    --arg section "$section" --arg task "$task" \
    --arg status "$status" --arg notes "$notes" \
    --arg hostname "$hostname" --arg user "$user" \
    '{timestamp:$timestamp,level:$level,section:$section,task:$task,status:$status,notes:$notes,hostname:$hostname,user:$user}')

  printf '%s\n' "$json_log" >> "$LOG_FILE"
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
  local task status notes
  read -r -p "Task description: " task
  while true; do
    read -r -p "Status (completed/skipped/failed): " status
    case "$status" in completed|skipped|failed) break ;; *) echo "Enter completed, skipped or failed." ;; esac
  done
  read -r -p "Notes (optional): " notes
  log_maintenance "QUICK" "$task" "$status" "$notes"
}

view_recent() {
  echo -e "\n${BLUE}Recent Maintenance Logs (last 20)${NC}"
  echo "════════════════════════════════════════════════════"
  if [[ ! -s "$LOG_FILE" ]]; then echo "No logs found."; return; fi

  local timestamp section task status color
  # fromjson? skips any malformed legacy line instead of aborting
  tail -n 20 "$LOG_FILE" \
    | jq -rR 'fromjson? | [.timestamp,.section,.task,.status] | @tsv' \
    | while IFS=$'\t' read -r timestamp section task status; do
        case "$status" in
          completed) color=$GREEN ;;
          failed)    color=$RED ;;
          skipped)   color=$YELLOW ;;
          *)         color=$NC ;;
        esac
        echo -e "${color}[$timestamp]${NC} $section: $task [$status]"
      done
}

show_stats() {
  echo -e "\n${BLUE}Maintenance Completion Statistics${NC}"
  echo "════════════════════════════════════════════════════"
  [[ -s "$LOG_FILE" ]] || { echo "No logs found."; return; }

  local cutoff
  cutoff=$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)

  echo -e "\n${YELLOW}Tasks by Status (Last 30 Days):${NC}"
  jq -r --arg c "$cutoff" 'select(.timestamp >= $c) | .status' "$LOG_FILE" 2>/dev/null \
    | sort | uniq -c | sort -rn

  echo -e "\n${YELLOW}Tasks by Section (Last 30 Days):${NC}"
  jq -r --arg c "$cutoff" 'select(.timestamp >= $c) | .section' "$LOG_FILE" 2>/dev/null \
    | sort | uniq -c | sort -rn | head -10

  echo -e "\n${YELLOW}Last Completion Dates by Section:${NC}"
  jq -r 'select(.status=="completed") | [.section,.timestamp] | @tsv' "$LOG_FILE" 2>/dev/null \
    | sort -k1,1 -k2,2 \
    | awk -F'\t' '{last[$1]=$2} END {for (s in last) print "  " s ": " substr(last[s],1,10)}' \
    | sort
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
  read -r -p "Task performed: " task

  echo ""
  echo "Status:"
  echo "  1) completed"
  echo "  2) skipped"
  echo "  3) failed"
  read -r -p "Select (1-3): " status_choice

  case "$status_choice" in
    1) status="completed" ;;
    2) status="skipped" ;;
    3) status="failed" ;;
    *) status="unknown" ;;
  esac

  read -r -p "Notes (optional): " notes

  log_maintenance "$section_code" "$task" "$status" "$notes"
}

ensure_log_file() {
  if [[ ! -f "$LOG_FILE" ]]; then
    if [[ -w "$(dirname "$LOG_FILE")" ]]; then
      touch "$LOG_FILE" && chmod 666 "$LOG_FILE"
    else
      echo -e "${RED}Error: Cannot create log file at $LOG_FILE${NC}" >&2
      echo "Run with sudo or check permissions" >&2
      exit 1
    fi
  fi
}

noninteractive() {
  local section="" task="" status="completed" notes=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --section) section="${2:?}"; shift 2 ;;
      --task)    task="${2:?}";    shift 2 ;;
      --status)  status="${2:?}";  shift 2 ;;
      --notes)   notes="${2:-}";   shift 2 ;;
      *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
  done
  [[ -n $section && -n $task ]] || {
    echo "usage: maintenance-log --section CODE --task TEXT [--status completed|skipped|failed] [--notes TEXT]" >&2
    exit 2
  }
  case "$status" in completed|skipped|failed) ;; *) echo "invalid status: $status" >&2; exit 2 ;; esac
  local valid=0 entry
  for entry in "${CHECKLIST_SECTIONS[@]}"; do [[ "${entry%%:*}" == "$section" ]] && valid=1; done
  [[ $section == QUICK ]] && valid=1
  (( valid )) || { echo "unknown section: $section (codes are listed in the menu)" >&2; exit 2; }
  ensure_log_file
  log_maintenance "$section" "$task" "$status" "$notes"
}

# Main loop
main() {
  while true; do
    show_menu
    read -r -p "Select option: " choice

    case "$choice" in
      q|Q)
        quick_log
        ;;
      v|V)
        view_recent
        read -r -p "Press Enter to continue..."
        ;;
      s|S)
        show_stats
        read -r -p "Press Enter to continue..."
        ;;
      x|X)
        echo -e "\n${GREEN}Goodbye!${NC}\n"
        exit 0
        ;;
      *)
        if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#CHECKLIST_SECTIONS[@]} )); then
          log_section_task $((choice - 1))
        else
          echo -e "${RED}Invalid option${NC}"
          sleep 1
        fi
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

if [[ $# -gt 0 ]]; then
  noninteractive "$@"
  exit 0
fi
ensure_log_file

main

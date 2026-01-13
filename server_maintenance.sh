#!/usr/bin/env bash
#===============================================================================
# Recipe Codes - Server Maintenance Script (CloudPanel-friendly)
#
# Copyright (c) 2023 Recipe Codes. All rights reserved.
#
# Goals:
#   - Safe update/upgrade for CloudPanel-supported distributions
#   - Basic security hardening (optional): unattended upgrades, UFW, fail2ban
#   - Safe PHP-FPM service management:
#       * Prevent "disable ALL" (guardrail)
#       * Strong warnings before disabling any PHP-FPM
#       * Support re-enabling previously disabled PHP-FPM services
#
# Notes:
#   - CloudPanel commonly runs on Debian/Ubuntu (apt-based). This script focuses
#     on apt-based systems and will refuse unsupported package managers.
#   - Always validate firewall rules before enabling UFW on remote servers.
#===============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/var/log/recipe-codes-server-maintenance.log"

# Behavior flags (override via environment variables)
NONINTERACTIVE="${NONINTERACTIVE:-0}"   # 1 = reduce prompts, defaults used
ASSUME_YES="${ASSUME_YES:-0}"           # 1 = auto-confirm prompts (dangerous)
APPLY_SECURITY="${APPLY_SECURITY:-1}"   # 0 = skip security steps
MANAGE_PHP="${MANAGE_PHP:-1}"           # 0 = skip PHP menu

#-------------------------------------------------------------------------------

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

log() {
  local msg="$*"
  echo "[$(timestamp)] $msg" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "This script must be run as root. Use: sudo $SCRIPT_NAME"
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

on_error() {
  local exit_code=$?
  local line_no=$1
  log "Script failed at line ${line_no} (exit code: ${exit_code}). Check ${LOG_FILE}."
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

#-------------------------------------------------------------------------------
# OS / distro detection (CloudPanel supported: focus apt-based)
#-------------------------------------------------------------------------------

get_os_release_value() {
  local key="$1"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    # Use indirect expansion for known fields
    case "$key" in
      ID) echo "${ID:-unknown}" ;;
      VERSION_ID) echo "${VERSION_ID:-unknown}" ;;
      PRETTY_NAME) echo "${PRETTY_NAME:-unknown}" ;;
      ID_LIKE) echo "${ID_LIKE:-unknown}" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

is_apt_based() {
  command_exists apt-get && [[ -f /etc/debian_version ]]
}

validate_cloudpanel_like_support() {
  # We do not hardcode a fragile list of exact versions here.
  # We enforce apt-based (Debian/Ubuntu family) as a safe operational boundary.
  local id version pretty id_like
  id="$(get_os_release_value ID)"
  version="$(get_os_release_value VERSION_ID)"
  pretty="$(get_os_release_value PRETTY_NAME)"
  id_like="$(get_os_release_value ID_LIKE)"

  log "Detected OS: ${pretty} (ID=${id}, VERSION_ID=${version}, ID_LIKE=${id_like})"

  if ! is_apt_based; then
    die "Unsupported system for this script: non-apt distribution detected. This script supports CloudPanel apt-based distributions (Debian/Ubuntu family)."
  fi
}

#-------------------------------------------------------------------------------
# Prompts
#-------------------------------------------------------------------------------

prompt_yn() {
  local prompt="$1"
  local default="${2:-n}" # y/n
  local ans

  if [[ "$ASSUME_YES" == "1" ]]; then
    echo "y"
    return 0
  fi

  if [[ "$NONINTERACTIVE" == "1" ]]; then
    echo "$default"
    return 0
  fi

  while true; do
    read -r -p "${prompt} [y/n] (default: ${default}): " ans || true
    ans="${ans:-$default}"
    case "$ans" in
      y|Y) echo "y"; return 0 ;;
      n|N) echo "n"; return 0 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

prompt_text() {
  local prompt="$1"
  local default="${2:-}"
  local ans

  if [[ "$NONINTERACTIVE" == "1" ]]; then
    echo "$default"
    return 0
  fi

  read -r -p "${prompt} " ans || true
  ans="${ans:-$default}"
  echo "$ans"
}

#-------------------------------------------------------------------------------
# APT maintenance
#-------------------------------------------------------------------------------

apt_update_upgrade() {
  log "Updating package lists..."
  apt-get update -y | tee -a "$LOG_FILE"

  log "Upgrading installed packages..."
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y | tee -a "$LOG_FILE"

  log "Performing distribution upgrade..."
  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y | tee -a "$LOG_FILE"

  log "Removing unused packages..."
  apt-get autoremove -y | tee -a "$LOG_FILE"

  log "Cleaning up package cache..."
  apt-get autoclean -y | tee -a "$LOG_FILE"
}

install_packages() {
  local pkgs=("$@")
  log "Installing packages: ${pkgs[*]}"
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" | tee -a "$LOG_FILE"
}

#-------------------------------------------------------------------------------
# Security hardening (optional)
#-------------------------------------------------------------------------------

setup_unattended_upgrades() {
  log "Configuring unattended-upgrades..."
  install_packages unattended-upgrades

  cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

  systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
  log "Unattended-upgrades enabled."
}

setup_ufw() {
  log "Configuring UFW..."
  install_packages ufw

  # Allow SSH baseline.
  ufw allow OpenSSH >/dev/null 2>&1 || ufw allow ssh >/dev/null 2>&1 || true

  if ufw status | grep -qi "Status: active"; then
    log "UFW already active. Skipping enable."
    return 0
  fi

  log "WARNING: Enabling UFW on remote servers can lock you out if SSH rules are incorrect."
  local ans
  ans="$(prompt_yn "Enable UFW firewall now?" "n")"
  if [[ "$ans" == "y" ]]; then
    ufw --force enable | tee -a "$LOG_FILE"
    log "UFW enabled."
  else
    log "UFW enable skipped."
  fi
}

setup_fail2ban() {
  log "Installing and enabling fail2ban..."
  install_packages fail2ban
  systemctl enable --now fail2ban >/dev/null 2>&1 || true
  log "fail2ban enabled."
}

improve_security() {
  log "Starting security hardening steps..."
  setup_unattended_upgrades
  setup_ufw
  setup_fail2ban
  log "Security hardening steps completed."
}

#-------------------------------------------------------------------------------
# PHP-FPM management with guardrails + re-enable support
#-------------------------------------------------------------------------------

STATE_DIR="/var/lib/recipe-codes"
DISABLED_PHP_STATE="${STATE_DIR}/disabled-php-fpm-services.txt"

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR" || true
  touch "$DISABLED_PHP_STATE" || true
  chmod 600 "$DISABLED_PHP_STATE" || true
}

systemd_unit_exists() {
  local base="$1" # without .service
  systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -qx "${base}.service"
}

list_installed_php_fpm_units() {
  # Enumerate php*-fpm.service units known to systemd
  systemctl list-unit-files 2>/dev/null \
    | awk '{print $1}' \
    | grep -E '^php[0-9]+\.[0-9]+-fpm\.service$' \
    | sed 's/\.service$//g' \
    | sort -V || true
}

list_disabled_php_fpm_units_from_state() {
  if [[ -f "$DISABLED_PHP_STATE" ]]; then
    grep -E '^php[0-9]+\.[0-9]+-fpm$' "$DISABLED_PHP_STATE" | sort -V | uniq || true
  fi
}

record_disabled_unit() {
  local unit="$1"
  ensure_state_dir
  # Avoid duplicates
  if ! grep -qx "$unit" "$DISABLED_PHP_STATE" 2>/dev/null; then
    echo "$unit" >>"$DISABLED_PHP_STATE"
  fi
}

remove_disabled_record() {
  local unit="$1"
  ensure_state_dir
  if [[ -f "$DISABLED_PHP_STATE" ]]; then
    grep -vx "$unit" "$DISABLED_PHP_STATE" >"${DISABLED_PHP_STATE}.tmp" || true
    mv "${DISABLED_PHP_STATE}.tmp" "$DISABLED_PHP_STATE"
    chmod 600 "$DISABLED_PHP_STATE" || true
  fi
}

disable_php_unit_safe() {
  local unit="$1"

  if ! systemd_unit_exists "$unit"; then
    log "PHP-FPM service ${unit}.service not found (skipping)."
    return 0
  fi

  log "About to stop/disable ${unit}.service"
  systemctl stop "${unit}.service" >/dev/null 2>&1 || true
  systemctl disable "${unit}.service" >/dev/null 2>&1 || true

  record_disabled_unit "$unit"
  log "${unit}.service disabled and recorded."
}

enable_php_unit_safe() {
  local unit="$1"

  if ! systemd_unit_exists "$unit"; then
    log "PHP-FPM service ${unit}.service not found (skipping)."
    remove_disabled_record "$unit"
    return 0
  fi

  log "Re-enabling ${unit}.service"
  systemctl enable "${unit}.service" >/dev/null 2>&1 || true
  systemctl start "${unit}.service" >/dev/null 2>&1 || true

  remove_disabled_record "$unit"
  log "${unit}.service enabled and started."
}

php_menu_disable_selected() {
  local units=()
  mapfile -t units < <(list_installed_php_fpm_units)

  if [[ "${#units[@]}" -eq 0 ]]; then
    log "No php*-fpm systemd services detected."
    return 0
  fi

  echo
  echo "Detected PHP-FPM services on this server:"
  local i=1
  for u in "${units[@]}"; do
    echo "  ${i}) ${u}"
    i=$((i+1))
  done
  echo

  # Guardrail: DO NOT provide a "disable ALL" option.
  echo "IMPORTANT WARNING:"
  echo "  Disabling PHP-FPM services can break web applications, CloudPanel sites,"
  echo "  and management components that rely on PHP."
  echo "  Disabling all PHP-FPM services may effectively take your server's web stack offline."
  echo

  local confirm
  confirm="$(prompt_yn "Proceed to disable ONE OR MORE PHP-FPM services?" "n")"
  if [[ "$confirm" != "y" ]]; then
    log "User declined PHP-FPM disable operation."
    return 0
  fi

  if [[ "$NONINTERACTIVE" == "1" ]]; then
    log "NONINTERACTIVE=1 set; refusing to disable PHP-FPM automatically. Run interactively or set explicit logic."
    return 0
  fi

  local choices
  choices="$(prompt_text "Enter numbers to disable (comma-separated), e.g., 1,3:" "")"
  choices="$(echo "$choices" | tr -d ' ')"

  if [[ -z "$choices" ]]; then
    log "No selection provided. Skipping."
    return 0
  fi

  IFS=',' read -r -a selected <<<"$choices"

  # Compute how many would be disabled
  local to_disable=()
  for idx in "${selected[@]}"; do
    if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#units[@]} )); then
      to_disable+=("${units[$((idx-1))]}")
    else
      log "Invalid selection '${idx}' (skipping)."
    fi
  done

  if [[ "${#to_disable[@]}" -eq 0 ]]; then
    log "No valid PHP-FPM selections."
    return 0
  fi

  # Hard safety: prevent disabling ALL detected services
  if [[ "${#to_disable[@]}" -ge "${#units[@]}" ]]; then
    log "REFUSED: selection would disable ALL PHP-FPM services."
    echo
    echo "REFUSED: You selected all detected PHP-FPM services."
    echo "Disabling all PHP-FPM services can take your server offline (CloudPanel + websites)."
    echo "Please leave at least one PHP-FPM service enabled."
    echo
    return 1
  fi

  echo
  echo "Final confirmation:"
  printf '  - Will disable: %s\n' "${to_disable[@]}"
  echo
  local final
  final="$(prompt_yn "Confirm disable of the above PHP-FPM services?" "n")"
  if [[ "$final" != "y" ]]; then
    log "User canceled at final confirmation."
    return 0
  fi

  for u in "${to_disable[@]}"; do
    disable_php_unit_safe "$u"
  done
}

php_menu_reenable() {
  ensure_state_dir
  local disabled=()
  mapfile -t disabled < <(list_disabled_php_fpm_units_from_state)

  if [[ "${#disabled[@]}" -eq 0 ]]; then
    log "No previously disabled PHP-FPM services recorded at ${DISABLED_PHP_STATE}."
    echo
    echo "No disabled PHP-FPM services recorded by this script."
    echo "If you disabled PHP-FPM outside this script, use: systemctl list-unit-files | grep php.*-fpm"
    echo
    return 0
  fi

  echo
  echo "PHP-FPM services previously disabled by this script:"
  local i=1
  for u in "${disabled[@]}"; do
    echo "  ${i}) ${u}"
    i=$((i+1))
  done
  echo "  A) Re-enable ALL listed above"
  echo

  if [[ "$NONINTERACTIVE" == "1" ]]; then
    log "NONINTERACTIVE=1 set; skipping re-enable menu."
    return 0
  fi

  local choice
  choice="$(prompt_text "Choose number(s) to re-enable (comma-separated) or 'A' for all:" "")"
  choice="$(echo "$choice" | tr -d ' ')"

  if [[ -z "$choice" ]]; then
    log "No selection provided. Skipping."
    return 0
  fi

  if [[ "$choice" == "A" || "$choice" == "a" ]]; then
    local ans
    ans="$(prompt_yn "Confirm re-enable ALL recorded PHP-FPM services?" "n")"
    if [[ "$ans" != "y" ]]; then
      log "User canceled re-enable all."
      return 0
    fi
    for u in "${disabled[@]}"; do
      enable_php_unit_safe "$u"
    done
    return 0
  fi

  IFS=',' read -r -a selected <<<"$choice"
  local to_enable=()
  for idx in "${selected[@]}"; do
    if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#disabled[@]} )); then
      to_enable+=("${disabled[$((idx-1))]}")
    else
      log "Invalid selection '${idx}' (skipping)."
    fi
  done

  if [[ "${#to_enable[@]}" -eq 0 ]]; then
    log "No valid selections for re-enable."
    return 0
  fi

  echo
  echo "Will re-enable:"
  printf '  - %s\n' "${to_enable[@]}"
  echo

  local ans
  ans="$(prompt_yn "Confirm re-enable selected services?" "n")"
  if [[ "$ans" != "y" ]]; then
    log "User canceled re-enable."
    return 0
  fi

  for u in "${to_enable[@]}"; do
    enable_php_unit_safe "$u"
  done
}

php_management_menu() {
  if [[ "$NONINTERACTIVE" == "1" ]]; then
    log "NONINTERACTIVE=1 set; skipping PHP management menu."
    return 0
  fi

  ensure_state_dir

  echo
  echo "PHP-FPM Management"
  echo "1) Disable selected PHP-FPM services (SAFE: cannot disable all)"
  echo "2) Re-enable PHP-FPM services disabled by this script"
  echo "3) Show detected PHP-FPM services"
  echo "4) Back / Skip"
  echo

  local opt
  opt="$(prompt_text "Choose an option:" "4")"

  case "$opt" in
    1) php_menu_disable_selected ;;
    2) php_menu_reenable ;;
    3)
      echo
      echo "Detected PHP-FPM services:"
      list_installed_php_fpm_units | sed 's/^/  - /'
      echo
      ;;
    *) log "Skipping PHP management." ;;
  esac
}

#-------------------------------------------------------------------------------
# Reboot
#-------------------------------------------------------------------------------

maybe_reboot() {
  local ans
  ans="$(prompt_yn "Maintenance completed. Reboot the server now?" "n")"
  if [[ "$ans" == "y" ]]; then
    log "Rebooting..."
    reboot
  else
    log "Exiting without reboot."
  fi
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
  require_root
  validate_cloudpanel_like_support

  touch "$LOG_FILE" >/dev/null 2>&1 || true
  log "Starting server maintenance..."

  apt_update_upgrade

  if [[ "$APPLY_SECURITY" == "1" ]]; then
    improve_security
  else
    log "Security steps skipped (APPLY_SECURITY=0)."
  fi

  if [[ "$MANAGE_PHP" == "1" ]]; then
    local ans
    ans="$(prompt_yn "Do you want to manage PHP-FPM services (disable/re-enable)?" "n")"
    if [[ "$ans" == "y" ]]; then
      php_management_menu
    else
      log "Skipping PHP management."
    fi
  else
    log "PHP management skipped (MANAGE_PHP=0)."
  fi

  log "Server maintenance completed."
  maybe_reboot
}

main "$@"

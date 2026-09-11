#!/usr/bin/env bash
# lib/utils.sh - Styling, logging, command execution with echo, and input helpers

# Color definitions
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

msg_info() {
    echo -e "${BLUE}${BOLD}[*]${RESET} $1"
}

msg_ok() {
    echo -e "${GREEN}${BOLD}[✓]${RESET} $1"
}

msg_warn() {
    echo -e "${YELLOW}${BOLD}[!]${RESET} $1"
}

msg_err() {
    echo -e "${RED}${BOLD}[✗]${RESET} $1"
}

msg_step() {
    echo -e "\n${MAGENTA}${BOLD}=== $1 ===${RESET}"
}

# Run a command with visual command printing, optional confirmation, and failure recovery loop
run_cmd() {
    local cmd=("$@")
    while true; do
        echo -e "${CYAN}${BOLD}> RUNNING:${RESET} ${YELLOW}${cmd[*]}${RESET}"
        if [ "${AUTO_MODE}" = false ]; then
            local user_confirm=""
            echo -ne "${YELLOW}${BOLD}Execute this command? [${GREEN}Y${RESET}/n/q(uit)]: ${RESET}"
            read -r user_confirm
            user_confirm=$(echo "$user_confirm" | tr '[:upper:]' '[:lower:]')
            if [ "$user_confirm" = "q" ] || [ "$user_confirm" = "quit" ]; then
                msg_err "Aborted by user."
                exit 1
            elif [ "$user_confirm" = "n" ] || [ "$user_confirm" = "no" ]; then
                msg_warn "Skipped: ${cmd[*]}"
                return 0
            fi
        fi

        set +e
        "${cmd[@]}"
        local status=$?
        set -e
        if [ "$status" -eq 0 ]; then
            return 0
        fi

        msg_err "Command failed with exit code $status: ${cmd[*]}"

        # Smart diagnostics for package managers
        if [[ "${cmd[*]}" =~ pacman|pacstrap|reflector|yay|paru ]]; then
            if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
                msg_warn "Network seems unreachable! Please check your internet connection."
            fi
            for lock in /var/lib/pacman/db.lck /mnt/var/lib/pacman/db.lck; do
                if [ -f "$lock" ]; then
                    msg_warn "Found stale pacman lock file: $lock. Removing it..."
                    rm -f "$lock" 2>/dev/null || sudo rm -f "$lock" 2>/dev/null || true
                fi
            done
        fi

        echo ""
        msg_warn "Failure Options for: ${cmd[*]}"
        echo -e "  [${GREEN}r${RESET}] ${BOLD}Retry${RESET} command (Default)"
        echo -e "  [${CYAN}s${RESET}] Drop to interactive ${BOLD}Shell${RESET} (fix network/mirrors, then type 'exit' to return)"
        echo -e "  [${YELLOW}i${RESET}] ${BOLD}Ignore${RESET} / Skip this failure and continue"
        echo -e "  [${RED}q${RESET}] ${BOLD}Quit${RESET} and abort installer"

        local action=""
        echo -ne "${BOLD}Choice [${GREEN}r${RESET}/s/i/q]: ${RESET}"
        read -r action
        action=$(echo "$action" | tr '[:upper:]' '[:lower:]')

        case "$action" in
            s|shell)
                msg_info "Opening interactive subshell. Type 'exit' when finished to resume installer."
                bash --norc -i || bash -i
                ;;
            i|ignore|skip)
                msg_warn "Ignored error. Continuing..."
                return 0
                ;;
            q|quit|abort)
                msg_err "Aborted by user."
                exit "$status"
                ;;
            r|retry|*)
                msg_info "Retrying command..."
                ;;
        esac
    done
}

# Run a command string in bash with visual printing, optional confirmation, and failure recovery loop
run_eval() {
    local cmd_str="$*"
    while true; do
        echo -e "${CYAN}${BOLD}> RUNNING:${RESET} ${YELLOW}${cmd_str}${RESET}"
        if [ "${AUTO_MODE}" = false ]; then
            local user_confirm=""
            echo -ne "${YELLOW}${BOLD}Execute this command? [${GREEN}Y${RESET}/n/q(uit)]: ${RESET}"
            read -r user_confirm
            user_confirm=$(echo "$user_confirm" | tr '[:upper:]' '[:lower:]')
            if [ "$user_confirm" = "q" ] || [ "$user_confirm" = "quit" ]; then
                msg_err "Aborted by user."
                exit 1
            elif [ "$user_confirm" = "n" ] || [ "$user_confirm" = "no" ]; then
                msg_warn "Skipped: ${cmd_str}"
                return 0
            fi
        fi

        set +e
        eval "${cmd_str}"
        local status=$?
        set -e
        if [ "$status" -eq 0 ]; then
            return 0
        fi

        msg_err "Command failed with exit code $status: ${cmd_str}"

        # Smart diagnostics for package managers
        if [[ "${cmd_str}" =~ pacman|pacstrap|reflector|yay|paru ]]; then
            if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
                msg_warn "Network seems unreachable! Please check your internet connection."
            fi
            for lock in /var/lib/pacman/db.lck /mnt/var/lib/pacman/db.lck; do
                if [ -f "$lock" ]; then
                    msg_warn "Found stale pacman lock file: $lock. Removing it..."
                    rm -f "$lock" 2>/dev/null || sudo rm -f "$lock" 2>/dev/null || true
                fi
            done
        fi

        echo ""
        msg_warn "Failure Options for: ${cmd_str}"
        echo -e "  [${GREEN}r${RESET}] ${BOLD}Retry${RESET} command (Default)"
        echo -e "  [${CYAN}s${RESET}] Drop to interactive ${BOLD}Shell${RESET} (fix network/mirrors, then type 'exit' to return)"
        echo -e "  [${YELLOW}i${RESET}] ${BOLD}Ignore${RESET} / Skip this failure and continue"
        echo -e "  [${RED}q${RESET}] ${BOLD}Quit${RESET} and abort installer"

        local action=""
        echo -ne "${BOLD}Choice [${GREEN}r${RESET}/s/i/q]: ${RESET}"
        read -r action
        action=$(echo "$action" | tr '[:upper:]' '[:lower:]')

        case "$action" in
            s|shell)
                msg_info "Opening interactive subshell. Type 'exit' when finished to resume installer."
                bash --norc -i || bash -i
                ;;
            i|ignore|skip)
                msg_warn "Ignored error. Continuing..."
                return 0
                ;;
            q|quit|abort)
                msg_err "Aborted by user."
                exit "$status"
                ;;
            r|retry|*)
                msg_info "Retrying command..."
                ;;
        esac
    done
}

# Interactive prompt with a default value
prompt_input() {
    local prompt_text="$1"
    local default_val="$2"
    local var_name="$3"
    local user_val=""

    if [ -n "$default_val" ]; then
        echo -ne "${BOLD}${prompt_text} [${GREEN}${default_val}${RESET}${BOLD}]: ${RESET}"
    else
        echo -ne "${BOLD}${prompt_text}: ${RESET}"
    fi

    read -r user_val
    if [ -z "$user_val" ]; then
        printf -v "$var_name" '%s' "$default_val"
    else
        printf -v "$var_name" '%s' "$user_val"
    fi
}

# Interactive password prompt with confirmation
prompt_password() {
    local prompt_text="$1"
    local var_name="$2"
    local pass1=""
    local pass2=""

    while true; do
        echo -ne "${BOLD}${prompt_text}: ${RESET}"
        read -rs pass1
        echo ""
        if [ -z "$pass1" ]; then
            msg_warn "Password cannot be empty. Try again."
            continue
        fi

        echo -ne "${BOLD}Confirm ${prompt_text}: ${RESET}"
        read -rs pass2
        echo ""

        if [ "$pass1" = "$pass2" ]; then
            printf -v "$var_name" '%s' "$pass1"
            break
        else
            msg_err "Passwords do not match! Please try again."
        fi
    done
}

# Interactive Yes/No prompt with a default
prompt_yes_no() {
    local prompt_text="$1"
    local default_choice="$2" # "Y" or "N"
    local var_name="$3"
    local choice=""

    local options="[y/n]"
    [ "$default_choice" = "Y" ] && options="[${GREEN}Y${RESET}/n]"
    [ "$default_choice" = "N" ] && options="[y/${GREEN}N${RESET}]"

    while true; do
        echo -ne "${BOLD}${prompt_text} ${options}: ${RESET}"
        read -r choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

        if [ -z "$choice" ]; then
            choice=$(echo "$default_choice" | tr '[:upper:]' '[:lower:]')
        fi

        if [ "$choice" = "y" ] || [ "$choice" = "yes" ]; then
            printf -v "$var_name" '%s' "true"
            break
        elif [ "$choice" = "n" ] || [ "$choice" = "no" ]; then
            printf -v "$var_name" '%s' "false"
            break
        else
            msg_warn "Please enter 'y' for yes or 'n' for no."
        fi
    done
}

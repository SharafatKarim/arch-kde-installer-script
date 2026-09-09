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

# Run a command with visual command printing and optional confirmation
run_cmd() {
    echo -e "${CYAN}${BOLD}> RUNNING:${RESET} ${YELLOW}$*${RESET}"
    if [ "${AUTO_MODE}" = false ]; then
        local user_confirm=""
        echo -ne "${YELLOW}${BOLD}Execute this command? [${GREEN}Y${RESET}/n/q(uit)]: ${RESET}"
        read -r user_confirm
        user_confirm=$(echo "$user_confirm" | tr '[:upper:]' '[:lower:]')
        if [ "$user_confirm" = "q" ] || [ "$user_confirm" = "quit" ]; then
            msg_err "Aborted by user."
            exit 1
        elif [ "$user_confirm" = "n" ] || [ "$user_confirm" = "no" ]; then
            msg_warn "Skipped: $*"
            return 0
        fi
    fi
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        msg_err "Command failed with exit code $status: $*"
        return $status
    fi
    return 0
}

# Run a command string in bash with visual printing and optional confirmation
run_eval() {
    echo -e "${CYAN}${BOLD}> RUNNING:${RESET} ${YELLOW}$*${RESET}"
    if [ "${AUTO_MODE}" = false ]; then
        local user_confirm=""
        echo -ne "${YELLOW}${BOLD}Execute this command? [${GREEN}Y${RESET}/n/q(uit)]: ${RESET}"
        read -r user_confirm
        user_confirm=$(echo "$user_confirm" | tr '[:upper:]' '[:lower:]')
        if [ "$user_confirm" = "q" ] || [ "$user_confirm" = "quit" ]; then
            msg_err "Aborted by user."
            exit 1
        elif [ "$user_confirm" = "n" ] || [ "$user_confirm" = "no" ]; then
            msg_warn "Skipped: $*"
            return 0
        fi
    fi
    eval "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        msg_err "Command failed with exit code $status: $*"
        return $status
    fi
    return 0
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
        eval "$var_name=\"$default_val\""
    else
        eval "$var_name=\"$user_val\""
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
            eval "$var_name=\"$pass1\""
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
            eval "$var_name=true"
            break
        elif [ "$choice" = "n" ] || [ "$choice" = "no" ]; then
            eval "$var_name=false"
            break
        else
            msg_warn "Please enter 'y' for yes or 'n' for no."
        fi
    done
}

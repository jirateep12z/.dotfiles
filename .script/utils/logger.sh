#!/usr/bin/env bash

readonly COLOR_RESET='\033[0;00m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[0;37m'
readonly COLOR_BOLD='\033[1;00m'

readonly ICON_ERROR="✗"
readonly ICON_SUCCESS="✓"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_DEBUG="⚙"

GetTimestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

Logger() {
    local log_type=""
    local log_message=""
    local show_timestamp=true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -type|--type)
                log_type="$2"
                shift 2
                ;;
            -message|--message)
                log_message="$2"
                shift 2
                ;;
            -no-timestamp|--no-timestamp)
                show_timestamp=false
                shift
                ;;
            *)
                echo -e "${COLOR_RED}Unknown parameter: $1${COLOR_RESET}" >&2
                return 1
                ;;
        esac
    done
    if [[ -z "$log_type" ]]; then
        echo -e "${COLOR_RED}Error: -type parameter is required${COLOR_RESET}" >&2
        return 1
    fi
    if [[ -z "$log_message" ]]; then
        echo -e "${COLOR_RED}Error: -message parameter is required${COLOR_RESET}" >&2
        return 1
    fi
    local timestamp=""
    if [[ "$show_timestamp" == true ]]; then
        timestamp="[$(GetTimestamp)] "
    fi
    case "${log_type^^}" in
        ERROR)
            echo -e "${COLOR_RED}${COLOR_BOLD}${timestamp}${ICON_ERROR} ERROR:${COLOR_RESET} ${COLOR_RED}${log_message}${COLOR_RESET}" >&2
            ;;
        SUCCESS)
            echo -e "${COLOR_GREEN}${COLOR_BOLD}${timestamp}${ICON_SUCCESS} SUCCESS:${COLOR_RESET} ${COLOR_GREEN}${log_message}${COLOR_RESET}"
            ;;
        WARNING|WARN)
            echo -e "${COLOR_YELLOW}${COLOR_BOLD}${timestamp}${ICON_WARNING} WARNING:${COLOR_RESET} ${COLOR_YELLOW}${log_message}${COLOR_RESET}"
            ;;
        INFO)
            echo -e "${COLOR_CYAN}${COLOR_BOLD}${timestamp}${ICON_INFO} INFO:${COLOR_RESET} ${COLOR_CYAN}${log_message}${COLOR_RESET}"
            ;;
        DEBUG)
            echo -e "${COLOR_MAGENTA}${COLOR_BOLD}${timestamp}${ICON_DEBUG} DEBUG:${COLOR_RESET} ${COLOR_MAGENTA}${log_message}${COLOR_RESET}"
            ;;
        *)
            echo -e "${COLOR_WHITE}${timestamp}${log_message}${COLOR_RESET}"
            ;;
    esac
    return 0
}

export -f Logger
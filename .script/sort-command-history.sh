#!/bin/bash

readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly FISH_HISTORY_PATH="${HOME}/.local/share/fish/fish_history"
readonly POWERSHELL_HISTORY_PATH="${HOME}/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt"
readonly OS_PATTERN_SUPPORTED="^(Darwin|Linux|MINGW*|MSYS*)"
readonly OS_PATTERN_UNIX="^(Darwin|Linux)"

declare history_file_path=""

function DisplayMessage() {
    local type=""
    local message=""
    local should_exit="false"
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            "-type")
                type="$2"
                shift 2
                ;;
            "-message")
                message="$2"
                shift 2
                ;;
            "-exit")
                should_exit="$2"
                shift 2
                ;;
            *)
                echo "ไม่รู้จัก parameter: $1" >&2
                return 1
                ;;
        esac
    done
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local color=""
    local reset_color="\033[0;00m"
    case "${type}" in
        "ERROR") color="\033[0;31m" ;;
        "INFO")  color="\033[0;32m" ;;
        "WARN")  color="\033[0;33m" ;;
        "DEBUG") color="\033[0;34m" ;;
        *)       color="\033[0;00m" ;;
    esac
    if [[ -z "$message" ]]; then
        echo -e "\033[0;31m[${timestamp}] - [ERROR]: ไม่พบข้อความที่จะแสดง\033[0;00m" >&2
        if [[ "$should_exit" == "true" ]]; then
            exit 1
        fi
        return 1
    fi
    echo -e "${color}[${timestamp}] - [${type}]: ${message}${reset_color}" >&2
    if [[ "${should_exit}" == "true" && "${type}" == "ERROR" ]]; then
        exit 1
    fi
}

function ValidateSystemEnvironment() {
    if [[ ! "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_SUPPORTED} ]]; then
        DisplayMessage -type "ERROR" -message "ไม่ได้รับการรองรับระบบ ${SYSTEM_OS_TYPE}" -exit true
    fi
}

function InitializeHistoryFilePath() {
    if [[ "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_UNIX} ]]; then
        history_file_path="${FISH_HISTORY_PATH}"
    else
        history_file_path="${POWERSHELL_HISTORY_PATH}"
    fi
    if [[ ! -f "${history_file_path}" ]]; then
        DisplayMessage -type "ERROR" -message "ไม่พบไฟล์ประวัติคำสั่งที่ ${history_file_path}" -exit true
    fi
    if [[ ! -r "${history_file_path}" ]]; then
        DisplayMessage -type "ERROR" -message "ไม่มีสิทธิ์ในการอ่านไฟล์ ${history_file_path}" -exit true
    fi
    if [[ ! -w "${history_file_path}" ]]; then
        DisplayMessage -type "ERROR" -message "ไม่มีสิทธิ์ในการเขียนไฟล์ ${history_file_path}" -exit true
    fi
}

function ProcessHistoryContent() {
    local temp_file="$(mktemp)"
    if [[ "${SYSTEM_OS_TYPE}" =~ ${OS_PATTERN_UNIX} ]]; then
        awk '!/^[[:space:]]*$/ && /^- [[:space:]]?cmd:/' "${history_file_path}" | \
        sort -u > "${temp_file}"
    else
        awk '!/^[[:space:]]*$/' "${history_file_path}" | \
        sort -u > "${temp_file}"
    fi
    if [[ ! -s "${temp_file}" ]]; then
        rm -f "${temp_file}"
        DisplayMessage -type "ERROR" -message "ไม่พบเนื้อหาหลังการประมวลผล" -exit true
    fi
    if ! cat "${temp_file}" > "${history_file_path}"; then
        rm -f "${temp_file}"
        DisplayMessage -type "ERROR" -message "ไม่สามารถเขียนผลลัพธ์กลับไปยังไฟล์เดิมได้" -exit true
    fi
    rm -f "${temp_file}"
}

function Main() {
    ValidateSystemEnvironment
    InitializeHistoryFilePath
    ProcessHistoryContent
    exit 0
}

Main
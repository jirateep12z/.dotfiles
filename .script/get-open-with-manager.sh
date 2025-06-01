#!/bin/bash

readonly COLOR_RED="\033[0;31m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_YELLOW="\033[0;33m"
readonly COLOR_BLUE="\033[0;34m"
readonly COLOR_RESET="\033[0;00m"

declare program_list=()
declare registry_paths=()
declare total_programs=0
declare missing_programs=0

function DisplayMessage() {
    local message_type=""
    local message_content=""
    local show_timestamp="false"
    local should_exit="false"
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            "-timer")
                show_timestamp="$2"
                shift 2
                ;;
            "-type")
                message_type="$2"
                shift 2
                ;;
            "-message")
                message_content="$2"
                shift 2
                ;;
            "-exit")
                should_exit="$2"
                shift 2
                ;;
            *)
                printf "Unknown parameter: %s\n" "$1" >&2
                return 1
                ;;
        esac
    done
    local timestamp_part=""
    if [[ "${show_timestamp}" == "true" ]]; then
        timestamp_part="[$(date '+%Y-%m-%d %H:%M:%S')] - "
    fi
    local color_code=""
    local type_part=""
    if [[ -n "${message_type}" ]]; then
        case "${message_type}" in
            "ERROR") color_code="$COLOR_RED" ;;
            "INFO")  color_code="$COLOR_GREEN" ;;
            "WARN")  color_code="$COLOR_YELLOW" ;;
            "DEBUG") color_code="$COLOR_BLUE" ;;
            *)       color_code="$COLOR_RESET" ;;
        esac
        type_part="[${message_type}]: "
    else
        color_code="$COLOR_RESET"
    fi
    if [[ -z "$message_content" ]]; then
        timestamp_part="[$(date '+%Y-%m-%d %H:%M:%S')] - "
        type_part="[ERROR]: "
        printf "%b%s%s%s%b\n" "$COLOR_RED" "$timestamp_part" "$type_part" "No message to display" "$COLOR_RESET" >&2
        if [[ "$should_exit" == "true" ]]; then
            exit 1
        fi
        return 1
    fi
    printf "%b%s%s%s%b\n" "$color_code" "$timestamp_part" "$type_part" "$message_content" "$COLOR_RESET" >&2
    if [[ "${should_exit}" == "true" && "${message_type}" == "ERROR" ]]; then
        exit 1
    fi
    return 0
}

function DisplaySeparator() {
    printf "%*s\n" "${2:-60}" | tr ' ' "${1:-=}" >&2
    return 0
}

function ValidateSystemEnvironment() {
    local os_type="$(uname -s)"
    case "${os_type}" in
        "MINGW"*|"MSYS"*|"CYGWIN"*)
            DisplayMessage -timer true -type "INFO" -message "Windows system detected (${os_type})"
            ;;
        *)
            DisplayMessage -timer true -type "ERROR" -message "This script only supports Windows (detected: ${os_type})"
            return 1
            ;;
    esac
    return 0
}

function CheckAdminPrivileges() {
    if command -v net >/dev/null 2>&1; then
        if net session >/dev/null 2>&1; then
            DisplayMessage -timer true -type "INFO" -message "Running as Administrator - Registry modification allowed"
        else
            DisplayMessage -timer true -type "WARN" -message "Not running as Administrator - Registry modification not allowed"
            return 1
        fi
    else
        DisplayMessage -timer true -type "WARN" -message "net.exe not found - Cannot check user privileges"
        return 1
    fi
    return 0
}

function FindProgramPath() {
    local program_name="$1"
    local program_path=""
    if [[ -z "${program_name}" ]]; then
        DisplayMessage -timer true -type "ERROR" -message "Program name not specified"
        return 1
    fi
    program_path="$(command -v "${program_name}" 2>/dev/null)"
    if [[ -n "${program_path}" && -f "${program_path}" ]]; then
        printf "${program_path}"
    fi
    local search_directories=(
        "/c/Program Files"
        "/c/Program Files (x86)"
        "${HOME}/AppData/Local/Programs"
    )
    for search_dir in "${search_directories[@]}"; do
        if [[ -d "${search_dir}" ]]; then
            program_path="$(find "${search_dir}" -name "${program_name}" -type f 2>/dev/null | head -1)"
            if [[ -n "${program_path}" ]]; then
                printf "${program_path}"
            fi
        fi
    done
    return 0
}

function EnumerateRegistryKeys() {
    local registry_path="$1"
    local key_list=()
    if [[ -z "${registry_path}" ]]; then
        DisplayMessage -timer true -type "ERROR" -message "Registry path not specified"
        return 1
    fi
    if command -v reg.exe >/dev/null 2>&1; then
        while IFS= read -r registry_key; do
            if [[ -n "${registry_key}" ]]; then
                key_list+=("${registry_key}")
            fi
        done < <(reg.exe query "${registry_path}" 2>/dev/null | grep -E "^\s*HKEY" | awk -F'\\' '{print $NF}')
        printf '%s\n' "${key_list[@]}"
    else
        DisplayMessage -timer true -type "ERROR" -message "reg.exe not found - Cannot read Registry"
        return 1
    fi
    return 0
}

function GetOpenWithPrograms() {
    local file_extension="${1:-*}"
    local registry_locations=()
    program_list=()
    registry_paths=()
    total_programs=0
    missing_programs=0
    DisplayMessage -timer true -type "INFO" -message "Searching for programs in Open With List for ${file_extension}"
    if [[ "${file_extension}" == "*" ]]; then
        registry_locations=(
            "HKEY_CLASSES_ROOT\\*\\OpenWithList"
            "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\*\\OpenWithList"
            "HKEY_CLASSES_ROOT\\Applications"
        )
    else
        registry_locations=(
            "HKEY_CLASSES_ROOT\\*\\OpenWithList"
            "HKEY_CLASSES_ROOT\\.${file_extension}\\OpenWithList"
            "HKEY_CLASSES_ROOT\\SystemFileAssociations\\.${file_extension}\\OpenWithList"
            "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\*\\OpenWithList"
            "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\.${file_extension}\\OpenWithList"
            "HKEY_CLASSES_ROOT\\Applications"
        )
    fi
    for registry_location in "${registry_locations[@]}"; do
        DisplayMessage -timer true -type "DEBUG" -message "Checking: ${registry_location}"
        local found_programs=()
        readarray -t found_programs < <(EnumerateRegistryKeys "${registry_location}")
        for program_name in "${found_programs[@]}"; do
            if [[ -n "${program_name}" ]]; then
                local program_path=""
                local status_message="Found"
                program_path="$(FindProgramPath "${program_name}")"
                if [[ -z "${program_path}" ]]; then
                    status_message="Missing"
                    ((missing_programs++))
                fi
                program_list+=("${program_name}")
                registry_paths+=("${registry_location}\\${program_name}")
                ((total_programs++))
                DisplayMessage -timer true -type "DEBUG" -message "Found program: ${program_name} (${status_message})"
            fi
        done
    done
    DisplayMessage -timer true -type "INFO" -message "Found ${total_programs} total programs (missing: ${missing_programs})"
    return 0
}

function DisplayPrograms() {
    if [[ "${total_programs}" -eq 0 ]]; then
        DisplayMessage -timer true -type "WARN" -message "No programs found in Open With List"
        return 1
    fi
    DisplaySeparator "="
    DisplayMessage -message "Programs in Open With List"
    DisplayMessage -message "Total: ${total_programs}"
    if [[ "${missing_programs}" -gt 0 ]]; then
        DisplayMessage -message "Missing programs: ${missing_programs}"
    fi
    DisplaySeparator "="
    for ((i=0; i<total_programs; i++)); do
        local program_name="${program_list[i]}"
        local registry_path="${registry_paths[i]}"
        local program_path=""
        local status_text="Found"
        program_path="$(FindProgramPath "${program_name}")"
        if [[ -z "${program_path}" ]]; then
            status_text="Not found [MISSING]"
        fi
        DisplayMessage -message "$(printf '[%2d] %s (%s)' "$((i+1))" "${program_name}" "${status_text}")"
        DisplayMessage -message "$(printf '     Registry Path: %s' "${registry_path}")"
        if [[ -n "${program_path}" ]]; then
            DisplayMessage -message "$(printf '     File Path: %s' "${program_path}")"
        else
            DisplayMessage -message "     File Path: Not found (may have been uninstalled)"
        fi
    done
    return 0
}

function RemoveRegistryKey() {
    local registry_key="$1"
    if [[ -z "${registry_key}" ]]; then
        DisplayMessage -timer true -type "ERROR" -message "Registry key not specified"
        return 1
    fi
    if command -v powershell.exe >/dev/null 2>&1; then
        if powershell.exe -Command "remove-item -path 'registry::${registry_key}' -recurse -force -erroraction silentlycontinue" 2>/dev/null; then
            DisplayMessage -timer true -type "INFO" -message "Successfully deleted Registry key: ${registry_key}"
            return 0
        else
            DisplayMessage -timer true -type "ERROR" -message "Failed to delete Registry key: ${registry_key}"
            return 1
        fi
    else
        DisplayMessage -timer true -type "ERROR" -message "powershell.exe not found"
        return 1
    fi
    return 0
}

function CleanMissingPrograms() {
    if [[ "${missing_programs}" -eq 0 ]]; then
        DisplayMessage -timer true -type "INFO" -message "No missing programs found"
        return 1
    fi
    DisplayMessage -timer true -type "INFO" -message "Found ${missing_programs} missing programs"
    local missing_count=0
    for ((i=0; i<total_programs; i++)); do
        local program_name="${program_list[i]}"
        local program_path=""
        program_path="$(FindProgramPath "${program_name}")"
        if [[ -z "${program_path}" ]]; then
            ((missing_count++))
            printf "  [%d] %s\n" "${missing_count}" "${program_name}"
        fi
    done
    read -p "Do you want to remove all ${missing_programs} missing programs? (Y/N): " -r confirm_removal
    if [[ "${confirm_removal^^}" != "Y" ]]; then
        DisplayMessage -timer true -type "INFO" -message "Operation cancelled"
        return 1
    fi
    if ! CheckAdminPrivileges; then
        DisplayMessage -timer true -type "ERROR" -message "Administrator privileges required to remove entries"
        read -p "Restart with Administrator privileges? (Y/N): " -r restart_admin
        if [[ "${restart_admin^^}" == "Y" ]]; then
            DisplayMessage -timer true -type "INFO" -message "Please restart the script with Administrator privileges"
            return 1
        fi
    fi
    local success_count=0
    local failed_count=0
    DisplayMessage -timer true -type "INFO" -message "Removing missing programs..."
    for ((i=0; i<total_programs; i++)); do
        local program_name="${program_list[i]}"
        local registry_path="${registry_paths[i]}"
        local program_path=""
        program_path="$(FindProgramPath "${program_name}")"
        if [[ -z "${program_path}" ]]; then
            if RemoveRegistryKey "${registry_path}"; then
                DisplayMessage -message "Removed ${program_name}"
                ((success_count++))
            else
                DisplayMessage -message "Failed to remove ${program_name}"
                ((failed_count++))
            fi
        fi
    done
    DisplayMessage -timer true -type "INFO" -message "Summary:"
    DisplayMessage -timer true -type "INFO" -message "Successfully removed: ${success_count}"
    if [[ "${failed_count}" -gt 0 ]]; then
        DisplayMessage -timer true -type "INFO" -message "Failed to remove: ${failed_count}"
    fi
    return 0
}

function InteractiveMenu() {
    while true; do
        DisplaySeparator "="
        DisplayMessage -message "Options"
        DisplaySeparator "="
        DisplayMessage -message "[D] Delete selected entry"
        DisplayMessage -message "[M] Remove all missing programs"
        DisplayMessage -message "[R] Refresh list"
        DisplayMessage -message "[Q] Quit program"
        read -p "Choose option (D/M/R/Q): " -r menu_choice
        menu_choice="${menu_choice^^}"
        case "${menu_choice}" in
            "D")
                if [[ "${total_programs}" -eq 0 ]]; then
                    DisplayMessage -timer true -type "WARN" -message "No entries to delete"
                    continue
                fi
                read -p "Enter entry number to delete (1-${total_programs}): " -r entry_index
                if [[ "${entry_index}" =~ ^[0-9]+$ ]] && [[ "${entry_index}" -ge 1 ]] && [[ "${entry_index}" -le "${total_programs}" ]]; then
                    local selected_index=$((entry_index - 1))
                    local selected_program="${program_list[selected_index]}"
                    local selected_registry="${registry_paths[selected_index]}"
                    DisplayMessage -message "Selected entry:"
                    DisplayMessage -message "Program: ${selected_program}"
                    DisplayMessage -message "Registry Path: ${selected_registry}"
                    read -p "Are you sure you want to delete this entry? (Y/N): " -r confirm_delete
                    if [[ "${confirm_delete^^}" == "Y" ]]; then
                        if RemoveRegistryKey "${selected_registry}"; then
                            DisplayMessage -timer true -type "INFO" -message "Entry deleted successfully!"
                            unset program_list[selected_index]
                            unset registry_paths[selected_index]
                            program_list=("${program_list[@]}")
                            registry_paths=("${registry_paths[@]}")
                            ((total_programs--))
                        else
                            DisplayMessage -timer true -type "ERROR" -message "Failed to delete entry"
                            DisplayMessage -message "You can manually delete it in Registry Editor at:"
                            DisplayMessage -message "${selected_registry}"
                        fi
                    else
                        DisplayMessage -timer true -type "INFO" -message "Operation cancelled"
                    fi
                else
                    DisplayMessage -timer true -type "ERROR" -message "Invalid number"
                fi
                ;;
            "M")
                CleanMissingPrograms
                ;;
            "R")
                DisplayMessage -timer true -type "INFO" -message "Refreshing list..."
                read -p "Enter file extension to check (leave blank for all types): " -r file_extension
                if [[ -z "${file_extension}" ]]; then
                    file_extension="*"
                fi
                GetOpenWithPrograms "${file_extension}"
                DisplayPrograms
                ;;
            "Q")
                DisplayMessage -timer true -type "INFO" -message "Exiting program"
                break
                ;;
            *)
                DisplayMessage -timer true -type "ERROR" -message "Please choose D, M, R, or Q"
                ;;
        esac
    done
    return 0
}

function Main() {
    DisplaySeparator "="
    DisplayMessage -message "Open With List Manager"
    DisplaySeparator "="
    ValidateSystemEnvironment
    if CheckAdminPrivileges; then
        DisplayMessage -message "Running as Administrator - Can modify entries"
    else
        DisplayMessage -message "Not running as Administrator - Cannot modify entries"
        DisplayMessage -message "(You can view and open Registry Editor to manually edit)"
    fi
    DisplayMessage -message "Retrieving data from Registry..."
    read -p $'Enter file extension to check (leave blank for all types): ' -r file_extension
    if [[ -z "${file_extension}" ]]; then
        file_extension="*"
    fi
    GetOpenWithPrograms "${file_extension}"
    DisplayPrograms
    if [[ "${total_programs}" -gt 0 ]]; then
        InteractiveMenu
    else
        DisplayMessage -timer true -type "WARN" -message "No entries found"
    fi
    return 0
}

Main
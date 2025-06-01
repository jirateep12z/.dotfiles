#!/bin/bash

readonly SYSTEM_OS_TYPE="$(uname -s)"
readonly FISH_HISTORY_PATH="${HOME}/.local/share/fish/fish_history"
readonly POWERSHELL_HISTORY_PATH="${HOME}/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt"
readonly OS_PATTERN_SUPPORTED="^(Darwin|Linux|MINGW*|MSYS*)"
readonly OS_PATTERN_UNIX="^(Darwin|Linux)"

readonly DEFAULT_SHELL_COMMANDS="
pwd
cd
cd /
cd ~
cd ..
cd -
ls
ls -A
ls -l
ls -l -A
mkdir
mkdir -p
cat
tig
less
clear
rm
rm -rf
rm -rf \"\$(brew --cache)\"
mv
mv -f
cp
cp -rf
touch
chmod
chmod +x
chmod -x
find
grep
ping
curl
ssh
wsl
brew
brew list
brew list --cask
brew install
brew install --cask
brew uninstall
brew uninstall --cask
brew pin
brew unpin
brew upgrade
brew upgrade -g
brew cleanup
brew cleanup --prune all
scoop
scoop list
scoop install
scoop uninstall
scoop hold
scoop unhold
scoop update
scoop update -a
scoop cleanup
scoop cleanup -a
scoop cache rm
scoop cache rm -a
nvm
nvm list
nvm use
nvm install
nvm uninstall
npm
npm init
npm list
npm list -g
npm install
npm install -g
npm update
npm update -g
npm uninstall
npm uninstall -g
npm cache clean
npm cache clean --force
npm start
npm run dev
npm run build
npm run format
ncu
ncu -g
ncu -i
ncu -i --format group
pip
pip list
pip install
pip install -r requirements.txt
pip uninstall
pip uninstall -r requirements.txt
pip install -U
pip install -U -r requirements.txt
pip freeze
pip freeze > requirements.txt
pip cache
pip cache purge
php
php artisan
php artisan make
php artisan make:controller
php artisan make:model
php artisan make:resource
php artisan make:middleware
php artisan make:seeder
php artisan make:request
php artisan make:migration
php artisan migrate
php artisan migrate:refresh
php artisan migrate:reset
php artisan migrate:rollback
php artisan migrate:status
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan optimize
php artisan serve
composer
composer install
composer update
composer require
composer remove
composer clear-cache
flutter
flutter doctor
flutter pub get
flutter pub upgrade
flutter clean
flutter run
flutter devices
flutter build apk
flutter build ios
flutter build web
dart
dart pub get
dart pub upgrade
docker
docker system
docker system df
docker system prune
docker system prune -a
docker system prune -a --volumes
docker compose
docker compose ps
docker compose ps -a
docker compose logs
docker compose logs -f
docker compose watch
docker compose up
docker compose up -d
docker compose up --build
docker compose up -d --build
docker compose down
docker compose down -v
docker compose down -v --remove-orphans
docker compose exec
git
git init
git clone
git clone git@github.com:
git clone https://github.com/
git status
git log
git diff
git show
git add
git reset
git commit
git commit -m
git branch
git branch -a
git branch -d
git branch --merged
git branch --no-merged
git checkout
git checkout -b
git remote
git remote -v
git remote add origin
git remote remove origin
git merge
git merge --abort
git merge --continue
git rebase
git rebase --abort
git rebase --continue
git rebase --interactive --root
git push origin \"\$(git rev-parse --abbrev-ref HEAD)\"
git push origin \"\$(git rev-parse --abbrev-ref HEAD)\" -f
git pull origin \"\$(git rev-parse --abbrev-ref HEAD)\"
git cz
lazygit
z
z -l
z -c
"

readonly CUSTOM_SHELL_COMMANDS="
ll
lla
npm i
npm i -g
g
g init
g clone
g clone git@github.com:
g clone https://github.com/
g ad
g rs
g st
g br
g ba
g bd
g bm
g bn
g ci 
g cm
g co
g cb
g remote
g remote -v
g remote add origin
g remote remove origin
g merge
g merge --abort
g merge --continue
g rebase
g rebase --abort
g rebase --continue
g rebase --interactive --root
g ps
g ps -f
g pl
g cz
lg
"

declare command_prefix=""
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
        command_prefix="- cmd:"
        history_file_path="${FISH_HISTORY_PATH}"
    else
        command_prefix=""
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

function ResetHistoryFile() {
    rm "$history_file_path"
    touch "$history_file_path"
}

function WriteCommandToHistory() {
    local command="$1"
    if [[ -z "$command" ]]; then
        DisplayMessage -type "ERROR" -message "ไม่พบคำสั่งที่ต้องการเขียนลงไฟล์ประวัติ" -exit true
    fi
    awk -v command_prefix="$command_prefix" '
    !/^[[:space:]]*$/ {
        gsub(/\\/, "", $0);
        if (command_prefix != "") {
            print command_prefix " " $0;
        } else {
            print $0;
        }
    }' <<< "$command" >> "$history_file_path"
}

function Main() {
    ValidateSystemEnvironment
    InitializeHistoryFilePath
    ResetHistoryFile
    WriteCommandToHistory "$DEFAULT_SHELL_COMMANDS"
    WriteCommandToHistory "$CUSTOM_SHELL_COMMANDS"
    exit 0
}

Main
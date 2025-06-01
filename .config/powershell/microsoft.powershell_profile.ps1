[console]::inputencoding = [console]::outputencoding = new-object system.text.utf8encoding

if (test-path alias:where) {
  remove-item alias:where -force
}

$profile_omp = "$psscriptroot/jirateep12_black.omp.json"
oh-my-posh init pwsh --config $profile_omp | invoke-expression

set-psreadlinekeyhandler -chord "enter" -function validateandacceptline
set-psreadlinekeyhandler -chord "enter" -scriptblock {
  sh "$ENV:USERPROFILE\AppData\Local\.script\sort-command-history.sh"
  [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
set-psreadlineoption -editmode emacs -bellstyle none

set-alias grep "findstr"
set-alias py "python3"
set-alias pip "pip3"
set-alias vim "nvim"
set-alias wind "windsurf"
set-alias g "git"
set-alias lg "lazygit"
set-alias tig "$env:userprofile\scoop\apps\git\current\usr\bin\tig.exe"
set-alias less "$env:userprofile\scoop\apps\git\current\usr\bin\less.exe"

function ls() {
  eza -g --icons
}

function la() {
  eza -g --icons -a
}

function ll() {
  eza -l -g --icons
}

function lla() {
  eza -l -g --icons -a
}

function initialize_command_history() {
  sh "$ENV:USERPROFILE\AppData\Local\.script\initialize-command-history.sh"
}

function where ($command) {
  get-command -name $command -erroraction silentlycontinue | select-object -expandproperty definition -erroraction silentlycontinue
}
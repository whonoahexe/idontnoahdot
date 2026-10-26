#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"

export PATH=$PATH:/home/noah/.spicetify
export PATH="$HOME/.cargo/bin:$PATH"

# gsd-browser: use Brave (no Chrome/Chromium installed)
export GSD_BROWSER_BROWSER_PATH=/usr/bin/brave

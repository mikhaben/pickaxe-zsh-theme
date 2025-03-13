
#  Use the 256-color or named color codes you like.
HOST_COLOR="%{$fg[yellow]%}"            # hostname
DIR_COLOR="%{$fg_bold[blue]%}"          # current directory
USER_COLOR="%{$fg[magenta]%}"           # regular user
ROOT_USER_COLOR="%{$fg_bold[red]%}"     # root user
RPROMPT_COLOR="%{$fg[white]%}"          # Right prompt info
ERROR_COLOR="%{$fg[red]%}"              # command failure message
# Git prompt settings
ZSH_THEME_GIT_PROMPT_PREFIX=" %{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}!"
ZSH_THEME_GIT_PROMPT_CLEAN=""

# Error char emoji
ERROR_CHARS=("🫠" "💀" "🐛" "💣" "👎" "🙈" "🔥" "🤡" "🚨" "🤯" "❗" "🥶")
FAIL_CHAR=${ERROR_CHARS[$((RANDOM % ${#ERROR_CHARS[@]}))]}
FAIL_MESSAGE="${FAIL_CHAR} FAIL"

# Helper: Return color for username and prompt arrows
function user_color {
  if [ $UID -eq 0 ]; then
    echo "${ROOT_USER_COLOR}"
  else
    echo "${USER_COLOR}"
  fi
}

# Prompt char function (returns arrows instead of $ or #)
function prompt_char {
  # echo "${HOST_COLOR}❱❱$(user_color)❱%{$reset_color%}"
  echo "$(user_color)❱%{$reset_color%}"
}

# PROMPT
# 1) On success, do nothing. On fail, print 'FAIL' (in red) + newline
# 2) Show user@host + current directory + git info on its own line
# 3) Show arrows (prompt_char) on a new line where the cursor lands
PROMPT='%(?, ,${ERROR_COLOR}${FAIL_MESSAGE}%{$reset_color%}
)
${RPROMPT_COLOR}$CONDA_DEFAULT_ENV $(node --version) %*%{$reset_color%}
$(user_color)%n%{$reset_color%}@${HOST_COLOR}%m%{$reset_color%}: ${DIR_COLOR}%~%{$reset_color%}$(git_prompt_info)
$(prompt_char) '

# Right prompt
# RPROMPT='${RPROMPT_COLOR} $CONDA_DEFAULT_ENV $(node --version) %*%{$reset_color%}'

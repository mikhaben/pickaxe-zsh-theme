
# Disable default Python virtual environment prompt
export VIRTUAL_ENV_DISABLE_PROMPT=1

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

# Helper: Detect if Nerd Font is installed
function has_nerd_font {
  # Check for explicit mode setting (like Powerlevel10k)
  # Set PICKAXE_MODE=nerdfont to enable Nerd Font icons
  # Set PICKAXE_MODE=emoji to force emoji fallback
  if [[ "$PICKAXE_MODE" == "nerdfont" ]]; then
    return 0
  elif [[ "$PICKAXE_MODE" == "emoji" ]]; then
    return 1
  fi

  # Auto-detect: assume Nerd Font is available by default
  # (most modern terminals support it if the font is installed)
  return 0
}

# Helper: Get Node.js icon
function node_icon {
  if has_nerd_font; then
    echo "\ued0d"  # Nerd Font Node.js icon
  else
    echo "🟢"
  fi
}

# Helper: Get Python icon
function python_icon {
  if has_nerd_font; then
    echo "\ue606"  # Nerd Font Python icon (devicon)
  else
    echo "🐍"
  fi
}

# Helper: Get time icon
function time_icon {
  if has_nerd_font; then
    echo "\uf43a"  # Nerd Font clock icon (alt)
  else
    echo "🕐"
  fi
}

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
  echo "$(user_color)→%{$reset_color%}"
}

# Helper: Get Python env with icon if active (conda or venv)
function conda_env_info {
  local env_name=""

  # Check for conda environment
  if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    env_name="$CONDA_DEFAULT_ENV"
  # Check for Python virtual environment
  elif [[ -n "$VIRTUAL_ENV" ]]; then
    env_name=$(basename "$VIRTUAL_ENV")
  fi

  # Display with icon if environment is active
  if [[ -n "$env_name" ]]; then
    echo "$(python_icon) $env_name  "
  fi
}

# Helper: Get node version with icon if node is available
function node_version_info {
  if command -v node &> /dev/null; then
    echo "$(node_icon) $(node --version)  "
  fi
}

# Helper: Get time with icon
function time_info {
  echo "$(time_icon) %*"
}

# PROMPT
# 1) On success, do nothing. On fail, print 'FAIL' (in red) + newline
# 2) Empty line
# 3) Show env info (python, node, time) on its own line
# 4) Show user@host + current directory + git info
# 5) Show prompt char on a new line where the cursor lands
PROMPT='%(?, ,${ERROR_COLOR}${FAIL_MESSAGE}%{$reset_color%}
)
${RPROMPT_COLOR}$(conda_env_info)$(node_version_info)$(time_info)%{$reset_color%}
$(user_color)%n%{$reset_color%}@${HOST_COLOR}%m%{$reset_color%}: ${DIR_COLOR}%~%{$reset_color%}$(git_prompt_info)
$(prompt_char) '

# Right prompt
# RPROMPT='${RPROMPT_COLOR} $CONDA_DEFAULT_ENV $(node --version) %*%{$reset_color%}'

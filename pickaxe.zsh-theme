# pickaxe — a two-line zsh prompt with env info, git status and loud failures.
#
# Works as an oh-my-zsh theme (ZSH_THEME="pickaxe") or standalone
# (`source pickaxe.zsh-theme` from .zshrc). Everything is computed once per
# prompt in hooks, without subshells; the only external commands are one
# `git status` inside repositories and `node --version` when $PATH changes.
#
# Settings — set them before the theme loads:
#   PICKAXE_MODE               nerdfont (default) | emoji
#   PICKAXE_PWD_MAX_LEN        path length before the middle collapses (40)
#   PICKAXE_CMD_MAX_EXEC_TIME  seconds before "took Xs" shows (5, as in Pure)
#   PICKAXE_ERROR_CHARS        array of emoji picked at random on failure
#   PICKAXE_COLOR_*            any %F color name or 0-255 number, see below

setopt prompt_subst
autoload -Uz add-zsh-hook
zmodload zsh/datetime   # $EPOCHREALTIME for command timing

# The prompt shows the venv itself.
export VIRTUAL_ENV_DISABLE_PROMPT=1

: ${PICKAXE_MODE:=nerdfont}
: ${PICKAXE_PWD_MAX_LEN:=40}
: ${PICKAXE_CMD_MAX_EXEC_TIME:=5}
(( ${+PICKAXE_ERROR_CHARS} )) || typeset -ga PICKAXE_ERROR_CHARS=(
  "🫠" "💀" "🐛" "💣" "👎" "🙈" "🔥" "🤡" "🚨" "🤯" "❗" "🥶"
)

: ${PICKAXE_COLOR_USER:=magenta}
: ${PICKAXE_COLOR_ROOT:=red}
: ${PICKAXE_COLOR_HOST:=yellow}
: ${PICKAXE_COLOR_DIR:=blue}
: ${PICKAXE_COLOR_INFO:=white}
: ${PICKAXE_COLOR_ERROR:=red}
: ${PICKAXE_COLOR_TIME:=yellow}
: ${PICKAXE_COLOR_GIT:=green}
: ${PICKAXE_COLOR_GIT_AHEAD:=cyan}
: ${PICKAXE_COLOR_GIT_DIRTY:=red}

typeset -gA _pickaxe_icon
if [[ $PICKAXE_MODE == emoji ]]; then
  _pickaxe_icon=(python "🐍" node "🟢" clock "🕐")
else
  _pickaxe_icon=(python $'\ue606' node $'\ued0d' clock $'\uf43a')
fi

# Per-prompt state, filled by the hooks below and read by $PROMPT.
typeset -g _pickaxe_status _pickaxe_env _pickaxe_pwd _pickaxe_git
typeset -g _pickaxe_cmd_start _pickaxe_node_path _pickaxe_node_version

# "1h 2m 3s" from whole seconds.
function _pickaxe_human_time {
  local -i d=$(( $1 / 86400 )) h=$(( $1 / 3600 % 24 )) m=$(( $1 / 60 % 60 )) s=$(( $1 % 60 ))
  local out
  (( d )) && out+="${d}d "
  (( h )) && out+="${h}h "
  (( m )) && out+="${m}m "
  REPLY="${out}${s}s"
}

# Failure line: emoji, FAIL, the exit code and whatever explains it.
#   FAIL 137 (KILL)          killed by a signal
#   FAIL 1 (0|1|0)           which stage of a pipeline failed
#   FAIL 1 (! inverted 0)    a leading `!` turned a success into a failure
# Ctrl-C (130) and Ctrl-Z (148) are the user's doing, not failures, so they stay quiet.
function _pickaxe_render_status {
  local -i pipefail=$1 code=$2; shift 2
  local -a pipe=("$@")
  local line

  if (( code != 0 && code != 130 && code != 148 )); then
    # What $? would be without a leading `!`: the last stage, or with pipefail
    # the rightmost failing one.
    local -i expected=${pipe[-1]} i
    if (( pipefail )); then
      expected=0
      for (( i = ${#pipe}; i > 0; i-- )); do
        (( pipe[i] )) && { expected=${pipe[i]}; break }
      done
    fi

    local detail
    if (( code != expected )); then
      detail="! inverted ${(j:|:)pipe}"
    elif (( ${#pipe} > 1 )); then
      detail="${(j:|:)pipe}"
    elif (( code > 128 && code - 128 < ${#signals} )); then
      detail="${signals[code - 127]}"
    fi

    local char="${PICKAXE_ERROR_CHARS[RANDOM % ${#PICKAXE_ERROR_CHARS} + 1]}"
    line="%F{$PICKAXE_COLOR_ERROR}${char} FAIL ${code}${detail:+ ($detail)}%f"
  fi

  if [[ -n $_pickaxe_cmd_start ]]; then
    local -i elapsed=$(( EPOCHREALTIME - _pickaxe_cmd_start ))
    if (( elapsed >= PICKAXE_CMD_MAX_EXEC_TIME )); then
      _pickaxe_human_time $elapsed
      line+="${line:+ }%F{$PICKAXE_COLOR_TIME}took ${REPLY}%f"
    fi
  fi

  _pickaxe_status="${line:+$line
}"
}

# Active Python env (venv wins over conda, it is the more specific one) and
# Node version, cached against $PATH so nvm/fnm switches still show up.
function _pickaxe_render_env {
  local out name
  if [[ -n $VIRTUAL_ENV ]]; then
    # uv and python -m venv put the project name in VIRTUAL_ENV_PROMPT; older
    # virtualenv wraps it as "(name) ".
    name="${${${VIRTUAL_ENV_PROMPT:-${VIRTUAL_ENV:t}}#\(}%\) }"
  elif [[ -n $CONDA_DEFAULT_ENV ]]; then
    name=$CONDA_DEFAULT_ENV
  fi
  [[ -n $name ]] && out+="${_pickaxe_icon[python]} ${name//\%/%%}  "

  if (( $+commands[node] )); then
    if [[ $PATH != $_pickaxe_node_path ]]; then
      _pickaxe_node_path=$PATH
      _pickaxe_node_version="$(command node --version 2>/dev/null)"
    fi
    [[ -n $_pickaxe_node_version ]] && out+="${_pickaxe_icon[node]} ${_pickaxe_node_version}  "
  fi

  _pickaxe_env=$out
}

# Paths up to PICKAXE_PWD_MAX_LEN chars show in full. Longer ones keep ~/first,
# then as many trailing dirs as fit, with … replacing only the overflow.
function _pickaxe_render_pwd {
  local full="${(%):-%~}" max=$PICKAXE_PWD_MAX_LEN
  local -a parts=("${(@s:/:)full}")
  if (( ${#full} > max && ${#parts} > 3 )); then
    local head="${(j:/:)parts[1,2]}" tail="${parts[-1]}" i
    for (( i = ${#parts} - 1; i > 2; i-- )); do
      (( ${#head} + 3 + ${#parts[i]} + 1 + ${#tail} > max )) && break
      tail="${parts[i]}/${tail}"
    done
    full="${head}/…/${tail}"
  fi
  _pickaxe_pwd="${full//\%/%%}"
}

# Branch (or short hash when detached), ⇡ahead ⇣behind, and file counts for
# conflicted (=), staged (+), unstaged (!) and untracked (?): "=1 +2 !3 ?4".
# A file that is both staged and unstaged counts in both.
# One porcelain v2 call gives all of it. --no-optional-locks keeps the prompt
# from taking index.lock while another git command runs.
function _pickaxe_render_git {
  _pickaxe_git=
  local out
  out="$(command git --no-optional-locks status --porcelain=v2 --branch \
    --ignore-submodules=dirty 2>/dev/null)" || return

  local line branch oid
  local -i ahead=0 behind=0 staged=0 unstaged=0 untracked=0 conflicted=0
  for line in "${(@f)out}"; do
    case $line in
      ('# branch.oid '*)  oid=${line#\# branch.oid } ;;
      ('# branch.head '*) branch=${line#\# branch.head } ;;
      ('# branch.ab '*)
        local -a ab=(${=line#\# branch.ab })
        ahead=${ab[1]#+} behind=${ab[2]#-} ;;
      ('1 '*|'2 '*)
        [[ ${line[3]} != . ]] && (( staged++ ))
        [[ ${line[4]} != . ]] && (( unstaged++ )) ;;
      ('u '*) (( conflicted++ )) ;;
      ('? '*) (( untracked++ )) ;;
    esac
  done
  [[ $branch == '(detached)' ]] && branch="@${oid[1,7]}"
  [[ -n $branch ]] || return

  local git=" %F{$PICKAXE_COLOR_GIT}${branch//\%/%%}%f"
  local sync
  local -a marks
  (( ahead ))      && sync+="⇡${ahead}"
  (( behind ))     && sync+="⇣${behind}"
  (( conflicted )) && marks+=("=${conflicted}")
  (( staged ))     && marks+=("+${staged}")
  (( unstaged ))   && marks+=("!${unstaged}")
  (( untracked ))  && marks+=("?${untracked}")
  [[ -n $sync ]]   && git+=" %F{$PICKAXE_COLOR_GIT_AHEAD}${sync}%f"
  (( ${#marks} ))  && git+=" %F{$PICKAXE_COLOR_GIT_DIRTY}${marks}%f"
  _pickaxe_git=$git
}

function _pickaxe_preexec {
  _pickaxe_cmd_start=$EPOCHREALTIME
}

function _pickaxe_precmd {
  # Both in one statement: any command in between would reset $pipestatus.
  local -a _st=($? $pipestatus)
  # Read before emulate, which resets it.
  local -i pipefail=0
  [[ -o pipefail ]] && pipefail=1
  emulate -L zsh

  # An empty Enter runs nothing, so it must not repeat the last failure.
  if [[ -n $_pickaxe_cmd_start ]]; then
    _pickaxe_render_status $pipefail "${_st[@]}"
  else
    _pickaxe_status=
  fi
  _pickaxe_cmd_start=

  _pickaxe_render_env
  _pickaxe_render_pwd
  _pickaxe_render_git
}

# First in line, so no other precmd hook can reset $? and $pipestatus before
# they are read. Re-sourcing the theme does not register the hooks twice.
precmd_functions=(_pickaxe_precmd ${precmd_functions:#_pickaxe_precmd})
add-zsh-hook preexec _pickaxe_preexec

# Root gets a bold red name and arrow instead of magenta.
typeset -g _pickaxe_user_color="%(!.%B%F{$PICKAXE_COLOR_ROOT}.%F{$PICKAXE_COLOR_USER})"

# 1) Failure / slow-command line, only when there is something to report
# 2) Empty line
# 3) Python env, Node version, clock
# 4) user@host: path and git status
# 5) Arrow where the cursor lands
PROMPT='${_pickaxe_status}
%F{$PICKAXE_COLOR_INFO}${_pickaxe_env}${_pickaxe_icon[clock]} %*%f
${_pickaxe_user_color}%n%f%b@%F{$PICKAXE_COLOR_HOST}%m%f: %B%F{$PICKAXE_COLOR_DIR}${_pickaxe_pwd}%f%b${_pickaxe_git}
${_pickaxe_user_color}→%f%b '
RPROMPT=

_pickaxe_render_env
_pickaxe_render_pwd
_pickaxe_render_git

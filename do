#!/usr/bin/env bash
set -eu -o pipefail

branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo unknown)
gitref=$(git rev-parse --short HEAD 2>/dev/null || echo latest)
bucket=circleci-binary-releases

if [[ "$branch" == "20.10" ]]; then
    version="20.10.12-${CIRCLE_BUILD_NUM-0}-${gitref}"
else
    version="0.0.0-${CIRCLE_BUILD_NUM-0}-dev-${gitref}"
fi

help_cross="Cross compile the Docker binaries"
cross() {
  VERSION="${version}" DOCKER_CROSSPLATFORMS="linux/amd64 linux/arm64" make cross
}

help_deploy_s3_binaries="Deploy built binaries to the S3 bucket"
deploy-s3-binaries() {
  if [[ ! -d bundles ]]; then
    echo "No binaries found to upload"
    exit 1
  fi

  echo "Deploying version: ${version}"
  echo

  aws --profile cci \
    s3 cp \
    --recursive bundles "s3://${bucket}/docker/${version}/"
}


### START FRAMEWORK ###
# Do Version 0.0.4
# This variable is used, but shellcheck can't tell.
# shellcheck disable=SC2034
help_self_update="Update the framework from a file.

Usage: $0 self-update FILENAME
"
self-update() {
    local source selfpath pattern
    source="$1"
    selfpath="${BASH_SOURCE[0]}"
    cp "$selfpath" "$selfpath.bak"
    pattern='/### START FRAMEWORK/,/END FRAMEWORK ###$/'
    (sed "${pattern}d" "$selfpath"; sed -n "${pattern}p" "$source") \
        > "$selfpath.new"
    mv "$selfpath.new" "$selfpath"
    chmod --reference="$selfpath.bak" "$selfpath"
}

# This variable is used, but shellcheck can't tell.
# shellcheck disable=SC2034
help_completion="Print shell completion function for this script.

Usage: $0 completion SHELL"
completion() {
    local shell
    shell="${1-}"

    if [ -z "$shell" ]; then
      echo "Usage: $0 completion SHELL" 1>&2
      exit 1
    fi

    case "$shell" in
      bash)
        (echo
        echo '_dotslashdo_completions() { '
        # shellcheck disable=SC2016
        echo '  COMPREPLY=($(compgen -W "$('"$0"' list)" "${COMP_WORDS[1]}"))'
        echo '}'
        echo 'complete -F _dotslashdo_completions '"$0"
        );;
      zsh)
cat <<EOF
_dotslashdo_completions() {
  local -a subcmds
  subcmds=()
  DO_HELP_SKIP_INTRO=1 $0 help | while read line; do
EOF
cat <<'EOF'
    cmd=$(cut -f1  <<< $line)
    cmd=$(awk '{$1=$1};1' <<< $cmd)

    desc=$(cut -f2- <<< $line)
    desc=$(awk '{$1=$1};1' <<< $desc)

    subcmds+=("$cmd:$desc")
  done
  _describe 'do' subcmds
}

compdef _dotslashdo_completions do
EOF
        ;;
     fish)
cat <<EOF
complete -e -c do
complete -f -c do
for line in (string split \n (DO_HELP_SKIP_INTRO=1 $0 help))
EOF
cat <<'EOF'
  set cmd (string split \t $line)
  complete -c do  -a $cmd[1] -d $cmd[2]
end
EOF
    ;;
    esac
}

list() {
    declare -F | awk '{print $3}'
}

# This variable is used, but shellcheck can't tell.
# shellcheck disable=SC2034
help_help="Print help text, or detailed help for a task."
help() {
    local item
    item="${1-}"
    if [ -n "${item}" ]; then
      local help_name
      help_name="help_${item//-/_}"
      echo "${!help_name-}"
      return
    fi

    if [ -z "${DO_HELP_SKIP_INTRO-}" ]; then
      type -t help-text-intro > /dev/null && help-text-intro
    fi
    for item in $(list); do
      local help_name text
      help_name="help_${item//-/_}"
      text="${!help_name-}"
      [ -n "$text" ] && printf "%-30s\t%s\n" "$item" "$(echo "$text" | head -1)"
    done
}

case "${1-}" in
  list) list;;
  ""|"help") help "${2-}";;
  *)
    if ! declare -F "${1}" > /dev/null; then
        printf "Unknown target: %s\n\n" "${1}"
        help
        exit 1
    else
        "$@"
    fi
  ;;
esac
### END FRAMEWORK ###

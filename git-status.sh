#!/bin/sh

git_status() {
  repo_info="$(git rev-parse --git-dir --is-inside-git-dir \
    --is-bare-repository --is-inside-work-tree \
    --short HEAD 2>/dev/null)"
  rev_parse_exit="$?"
  if [ -z "$repo_info" ]; then
    return $rev_parse_exit
  fi
  short_sha="$(echo "$repo_info" | tail -n1)"

  # Main git command
  out=$(git status -z --porcelain --ignore-submodules --branch -uno \
    2>/dev/null | head -100)
  # Head line of status --branch
  h="$(echo "${out#\#\# }" | head -n1)"
  # Porcelain branch status [ahead x, behind y]
  # if [ "$s" = *\[*\] ]
  # Extract info between brackets
  s="$(echo "$h" | cut -d "[" -f2 | cut -d "]" -f1)"
  if [ "$s" = "$h" ]; then
    # Nothing matched
    s=""
  fi
  # Strip parsed local repository status
  branch_info="${h#$s}"
  ## master...origin/master
  case "$branch_info" in
    "HEAD (no branch)") branch="$short_sha" ;;
    *...*) branch="${branch_info%...*}" ;;
    *) branch="$branch_info" ;;
  esac
  while [ -n "$s" ]; do
    case $s in
      # "") break 2 ;;
      ,*) s="${s#,}" ;;
      ahead\ *)
        s="${s#ahead }"
        ahead="${s%%,*}"
        ;;
      behind\ *)
        s="${s#behind }"
        behind=""
        ;;
      *)
        echo >&2 "$s: invalid string"
        exit 1
        ;;
    esac
  done
  [ -n "$behind" ] && flags="$flags<"
  [ -n "$ahead" ] && flags="$flags>"
  # Number of reported files TODO -1
  c="$(echo "$out" | wc -l)"
  if [ "$c" -gt 0 ]; then
    flags="$flags*"
    # if [ "$branch" == "master" ]; then
    #   branch_color="red"
    # else
    #   branch_color="orange"
    # fi
    ret=2 # Indicates uncommitted changes
  fi
  # if [ -n "$behind" ] || [ -n "$ahead" ]; then
  #   branch_color="yellow"
  # fi
  printf 'on %s%s' "$branch" "$flags"
  # $cmd | while read -r line; do
  #   case "${line:0:2}" in # $line | head -c2
  #     \#\#) branch_info="${line#\#\# }" ;;
  #     *) ((count++)) ;;
  #     # ?M) ((changed++)) ;;
  #     # ?A) ((added++)) ;;
  #     # ?D) ((deleted++)) ;;
  #     # U?) ((updated++)) ;;
  #     # \?\?) ((untracked++)) ;;
  #     # *) ((staged++)) ;;
  #   esac
  # done
  return $ret
}

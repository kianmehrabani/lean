#!/bin/sh

GIT_STATUS_OTHER_RET="2"

git_status() {
  # --git-dir --is-inside-git-dir --is-bare-repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return $?
  fi
  prefix="${1:-on }"      # format="${1:-on %s%s}"
  # branch_format, flags_format?
  dirty_format="${2:-%s}" # Dirty repository
  other_format="${3:-%s}" # unstaged, unmerged...?
  clean_format="${4:-%s}" # Clean repository
  tmpdir=$(mktemp -d -t git.status)
  tmpfile="$tmpdir/porcelain.fifo"
  mkfifo "$tmpfile" # TODO mktmp to avoid collision?
  git status --porcelain=v2 --ignore-submodules --branch \
    >"$tmpfile" &
  # --untracked-files[=<mode>] (no, normal, default: all)
  # --ignore-submodules[=<when>] (none, untracked, dirty, default: all)
  count=0
  while read -r line; do
    case "$line" in
      # https://git-scm.com/docs/git-status#_branch_headers
      "# branch.oid "*) oid="${line#\# branch.oid }" ;; # Current commit (or initial)
      "# branch.head "*) head="${line#\# branch.head }" ;; # Current branch (or detached)
      "# branch.upstream "*) upstream="${line#\# branch.upstream }" ;; # If upstream is set
      "# branch.ab "*) ab="${line#\# branch.ab }" ;; # If upstream is set and the commit is present

      # https://git-scm.com/docs/git-status#_changed_tracked_entries
      # Ordinary changed entries have the following format:
      # 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
      # Renamed or copied entries have the following format:
      # 2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path><sep><origPath>
      # Unmerged entries have the following format:
      # u <xy> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>
      # Untracked items have the following format:
      # ? <path>
      # Ignored items have the following format:
      # ! <path>

      1* | 2* | u* | \?* | !*) count=$((count + 1)) ;;
      *) # echo >&2 "$line: invalid git status line"
        return 1
        ;;
    esac
  done <"$tmpfile"
  rm "$tmpfile" && rmdir "$tmpdir" # rm -R "$tmpdir"
  # echo "oid: $oid"
  # echo "head: $head"
  # echo "upstream: $upstream"
  # echo "ab: $ab"
  branch="${head:-$(echo "$oid" | cut -c-7)}"
  if [ "${GIT_STATUS_UPSTREAM:-0}" -eq 1 ] && [ -n "$upstream" ]; then
    branch="$branch...$upstream"
  fi

  # branch.ab +<ahead> -<behind>
  ahead=0
  behind=0
  if [ -n "$ab" ]; then
    ahead="${ab% -*}"
    ahead="${ahead#+}"
    behind="${ab#+* }"
    behind="${behind#-}"
  fi

  flags=
  [ "$behind" -gt 0 ] && flags="$flags>"
  [ "$ahead" -gt 0 ] && flags="$flags<"
  if [ "$count" -gt 0 ]; then
    flags="$flags*"
    # shellcheck disable=SC2059
    branch="$(printf "$dirty_format" "$branch")"
  elif [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
    # shellcheck disable=SC2059
    branch="$(printf "$other_format" "$branch")"
  else
    prefix="$clean_format$prefix"
  fi

  printf "%s%s%s" "$prefix" "$branch" "$flags"

  ret=0
  [ "$count" -gt 0 ] && ret="${GIT_STATUS_OTHER_RET}"
  return $ret
}

# git_status "$@"

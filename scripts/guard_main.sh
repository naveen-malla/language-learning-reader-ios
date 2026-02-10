#!/bin/zsh
set -euo pipefail

MODE="check"
ALLOW_DIRTY=false
MAIN_BRANCH="main"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/guard_main.sh
  ./scripts/guard_main.sh --cleanup
  ./scripts/guard_main.sh --cleanup --allow-dirty

Modes:
  check       Validate repo hygiene (default).
  --cleanup   Enforce main-only state for local branches/worktrees and prune stale refs.

Flags:
  --allow-dirty  Allow cleanup even when working tree is dirty.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --cleanup)
      MODE="cleanup"
      ;;
    --allow-dirty)
      ALLOW_DIRTY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR=$(cd "$(dirname "${(%):-%N}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

local_worktree_paths() {
  git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}'
}

local_non_main_branches() {
  git for-each-ref --format='%(refname:short)' refs/heads | grep -v "^${MAIN_BRANCH}$" || true
}

remote_non_main_tracking_refs() {
  git for-each-ref --format='%(refname)' refs/remotes/origin | grep -vE "refs/remotes/origin/(HEAD|${MAIN_BRANCH})$" || true
}

remote_non_main_heads() {
  git ls-remote --heads origin | awk '{print $2}' | sed 's#refs/heads/##' | grep -v "^${MAIN_BRANCH}$" || true
}

show_state() {
  local current_branch dirty local_branches remote_tracking remote_heads
  current_branch=$(git branch --show-current || true)
  dirty=$(git status --porcelain)
  local_branches=$(local_non_main_branches)
  remote_tracking=$(remote_non_main_tracking_refs)
  remote_heads=$(remote_non_main_heads)

  echo "Current branch: ${current_branch:-detached}"
  if [[ -n "$dirty" ]]; then
    echo "Working tree: dirty"
  else
    echo "Working tree: clean"
  fi

  local wt_count=0
  while IFS= read -r _; do
    ((wt_count += 1))
  done < <(local_worktree_paths)
  echo "Linked worktrees: $wt_count"

  if [[ -n "$local_branches" ]]; then
    echo "Local non-main branches:"
    echo "$local_branches" | sed 's/^/  - /'
  fi
  if [[ -n "$remote_tracking" ]]; then
    echo "Remote tracking refs (origin, non-main):"
    echo "$remote_tracking" | sed 's/^/  - /'
  fi
  if [[ -n "$remote_heads" ]]; then
    echo "Remote origin heads (non-main):"
    echo "$remote_heads" | sed 's/^/  - /'
  fi
}

if [[ "$MODE" == "cleanup" ]]; then
  dirty=$(git status --porcelain)
  if [[ -n "$dirty" && "$ALLOW_DIRTY" != true ]]; then
    echo "Cleanup blocked: working tree is dirty. Commit/stash first or use --allow-dirty."
    exit 2
  fi

  current_branch=$(git branch --show-current || true)
  if [[ "$current_branch" != "$MAIN_BRANCH" ]]; then
    git switch "$MAIN_BRANCH"
  fi

  git fetch --prune origin >/dev/null 2>&1 || true

  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    git update-ref -d "refs/heads/$branch" || true
  done < <(local_non_main_branches)

  while IFS= read -r wt; do
    [[ -z "$wt" ]] && continue
    if [[ "$wt" != "$REPO_ROOT" ]]; then
      git worktree remove --force "$wt" || true
    fi
  done < <(local_worktree_paths)
  git worktree prune

  while IFS= read -r tracking_ref; do
    [[ -z "$tracking_ref" ]] && continue
    git update-ref -d "$tracking_ref" || true
  done < <(remote_non_main_tracking_refs)

  while IFS= read -r remote_branch; do
    [[ -z "$remote_branch" ]] && continue
    git push origin --delete "$remote_branch" >/dev/null 2>&1 || true
  done < <(remote_non_main_heads)

  git fetch --prune origin >/dev/null 2>&1 || true
fi

show_state

current_branch=$(git branch --show-current || true)
local_branches=$(local_non_main_branches)
remote_tracking=$(remote_non_main_tracking_refs)
remote_heads=$(remote_non_main_heads)
extra_worktrees=$(local_worktree_paths | grep -v "^${REPO_ROOT}$" || true)

if [[ "$current_branch" != "$MAIN_BRANCH" ]]; then
  echo "FAIL: current branch is not '${MAIN_BRANCH}'."
  exit 1
fi
if [[ -n "$local_branches" ]]; then
  echo "FAIL: local non-main branches still exist."
  exit 1
fi
if [[ -n "$extra_worktrees" ]]; then
  echo "FAIL: extra linked worktrees still exist."
  exit 1
fi
if [[ -n "$remote_tracking" ]]; then
  echo "FAIL: stale non-main origin tracking refs still exist."
  exit 1
fi
if [[ -n "$remote_heads" ]]; then
  echo "FAIL: non-main branches still exist on origin."
  exit 1
fi

echo "PASS: repository is in main-only hygiene state."

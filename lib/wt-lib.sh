#!/usr/bin/env bash
# Shared library functions for worktree workflow scripts

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Error handling
error() {
  echo -e "  ${RED}Error: $1${NC}" >&2
  exit 1
}

warn() {
  echo -e "  ${YELLOW}Warning: $1${NC}" >&2
}

info() {
  echo -e "  ${BLUE}$1${NC}"
}

success() {
  echo -e "  ${GREEN}$1${NC}"
}

# Git repository checks
ensure_git_repo() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not a git repository. Please run this command from within a git repository."
  fi
}

get_repo_root() {
  git rev-parse --show-toplevel
}

# Check if wt is initialized (wt-working branch exists)
is_initialized() {
  git show-ref --verify --quiet refs/heads/wt-working
}

ensure_initialized() {
  if ! is_initialized; then
    error "Worktree workflow not initialized. Run 'wt init' first."
  fi
}

# Get worktree path for a given branch name (returns relative path)
get_worktree_path() {
  local branch="$1"
  local repo_root
  repo_root=$(get_repo_root)

  # Parse git worktree list to find the path for this branch
  # Returns path relative to repo root
  git worktree list --porcelain | awk -v branch="$branch" -v root="$repo_root" '
    /^worktree / { path = substr($0, 10) }
    /^branch / {
      if ($2 == "refs/heads/" branch && path != root) {
        # Strip root prefix to get relative path
        if (index(path, root "/") == 1) {
          print substr(path, length(root) + 2)
        } else {
          print path
        }
        exit
      }
    }
  '
}

# Check if worktree exists for a given branch name
worktree_exists() {
  local branch="$1"
  local path
  path=$(get_worktree_path "$branch")
  [[ -n "$path" ]]
}

# Get all worktree branch names (excluding main repo)
list_worktree_names() {
  local repo_root
  repo_root=$(get_repo_root)

  git worktree list --porcelain | awk -v root="$repo_root" '
    /^worktree / { path = substr($0, 10) }
    /^branch / {
      if (path != root) {
        # Extract branch name from refs/heads/branch-name
        split($2, parts, "/")
        branch = parts[3]
        for (i = 4; i <= length(parts); i++) {
          branch = branch "/" parts[i]
        }
        print branch
      }
    }
  '
}

# Get worktree branch (same as name in our model)
get_worktree_branch() {
  echo "$1"
}

# Verify worktree directory exists
verify_worktree_exists() {
  local name="$1"
  local path
  path=$(get_worktree_path "$name")

  if [[ -z "$path" ]]; then
    error "Worktree '$name' not found"
  fi

  if [[ ! -d "$path" ]]; then
    error "Worktree directory '$path' does not exist"
  fi
}

# Check if on protected branch
is_protected_branch() {
  local branch
  branch=$(git branch --show-current)

  [[ "$branch" == "main" ]] || [[ "$branch" == "master" ]]
}

ensure_not_protected_branch() {
  if is_protected_branch; then
    error "Cannot perform this operation on main/master branch"
  fi
}

# Check for uncommitted changes
has_uncommitted_changes() {
  # Check for modified/staged files
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    return 0
  fi

  # Check for untracked files
  if [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    return 0
  fi

  return 1
}

# Extract unique directories from a list of file paths
# Input: newline-separated list of file paths
# Output: newline-separated list of unique directories (sorted)
extract_directories() {
  local files="$1"
  local directories=()

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    local dir
    dir=$(dirname "$file")
    if [[ "$dir" != "." ]]; then
      directories+=("$dir")
    fi
  done <<< "$files"

  # Sort and deduplicate
  printf '%s\n' "${directories[@]}" | sort -u
}

# Expand directory selections from fzf into individual files
# Input: $1 = selected items (newline-separated, may include dirs with trailing /)
#        $2 = all available files (newline-separated)
# Output: expanded list of files (newline-separated)
expand_directory_selections() {
  local selected="$1"
  local all_files="$2"
  local result=()

  while IFS= read -r item; do
    [[ -z "$item" ]] && continue

    # Check if it's a directory (ends with /)
    if [[ "$item" == */ ]]; then
      # Remove trailing slash
      local dir="${item%/}"
      # Add all files in this directory
      while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ "$file" == "${dir}/"* ]]; then
          result+=("$file")
        fi
      done <<< "$all_files"
    else
      # It's a file
      result+=("$item")
    fi
  done <<< "$selected"

  # Output results
  printf '%s\n' "${result[@]}"
}

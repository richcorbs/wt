#!/usr/bin/env bash
# Unassign a file from a worktree

show_help() {
  cat <<EOF
Usage: wt unassign <file|abbreviation|.> <worktree>

Unassign file(s) from a worktree by reverting their commits in worktree-staging
and removing the changes from the worktree. The files will show up as
"unassigned" again.

Arguments:
  file|abbreviation|.  File path, two-letter abbreviation, or . for all assigned files
  worktree             Name of the worktree

Options:
  -h, --help    Show this help message

Examples:
  wt unassign ab feature-auth                # Single file by abbreviation
  wt unassign app/models/user.rb feature-auth # Single file by path
  wt unassign . feature-auth                 # All uncommitted files assigned to the worktree
EOF
}

cmd_unassign() {
  # Parse arguments
  local file_or_abbrev=""
  local worktree_name=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        if [[ -z "$file_or_abbrev" ]]; then
          file_or_abbrev="$1"
        elif [[ -z "$worktree_name" ]]; then
          worktree_name="$1"
        else
          error "Too many arguments"
        fi
        ;;
    esac
    shift
  done

  # Validate arguments
  if [[ -z "$file_or_abbrev" ]]; then
    error "Missing required argument: file or abbreviation"
  fi

  if [[ -z "$worktree_name" ]]; then
    error "Missing required argument: worktree"
  fi

  # Ensure initialized
  ensure_git_repo
  ensure_initialized

  # Ensure on worktree-staging
  local current_branch
  current_branch=$(git branch --show-current)
  if [[ "$current_branch" != "worktree-staging" ]]; then
    error "Must be on worktree-staging branch to unassign. Current branch: ${current_branch}"
  fi

  # Check if worktree exists
  if ! worktree_exists "$worktree_name"; then
    error "Worktree '$worktree_name' not found"
  fi

  # Check if unassigning all files
  if [[ "$file_or_abbrev" == "." ]]; then
    info "Unassigning all files from '${worktree_name}'..."

    # Find all assignment commits for this worktree
    local files_to_restore=()

    while IFS= read -r sha; do
      local msg
      msg=$(git log -1 --format="%s" "$sha")

      if [[ "$msg" =~ ^wt:\ assign\ (.*)\ to\ ${worktree_name}$ ]]; then
        local filepath="${BASH_REMATCH[1]}"
        files_to_restore+=("$filepath:$sha")
      fi
    done < <(git log --format="%H" -n 100)  # Search last 100 commits

    if [[ ${#files_to_restore[@]} -eq 0 ]]; then
      warn "No assignment commits found for '${worktree_name}'"
      exit 0
    fi

    info "Found ${#files_to_restore[@]} file(s) to unassign"

    # Restore each file to its pre-assignment state
    for file_commit in "${files_to_restore[@]}"; do
      local filepath="${file_commit%:*}"
      local commit_sha="${file_commit#*:}"
      local parent_commit="${commit_sha}^"

      info "Unassigning ${filepath}..."

      # Check if file existed before assignment
      if git cat-file -e "${parent_commit}:${filepath}" 2>/dev/null; then
        # File existed - restore to previous version
        git show "${parent_commit}:${filepath}" > "${filepath}"
        git add "${filepath}"
      else
        # File didn't exist - delete it
        git rm "${filepath}" 2>/dev/null || rm -f "${filepath}"
      fi
    done

    success "Unassigned all files from '${worktree_name}'"
    info "Files are now unassigned in worktree-staging"
    echo ""
    source "${WT_ROOT}/commands/status.sh"
    cmd_status
    exit 0
  fi

  # Find the commit that assigned this file to this worktree
  info "Searching for assignment commit..."

  local filepath="$file_or_abbrev"
  local commit_sha=""
  local commit_msg="wt: assign ${filepath} to ${worktree_name}"

  # Search recent commits for the assignment
  while IFS= read -r sha; do
    local msg
    msg=$(git log -1 --format="%s" "$sha")

    if [[ "$msg" == "$commit_msg" ]]; then
      commit_sha="$sha"
      break
    fi
  done < <(git log --format="%H" -n 50)  # Search last 50 commits

  if [[ -z "$commit_sha" ]]; then
    error "Could not find assignment commit for '${filepath}' to '${worktree_name}'"
  fi

  local short_sha
  short_sha=$(git rev-parse --short "$commit_sha")

  info "Found assignment commit: ${short_sha}"

  # Restore file to pre-assignment state
  info "Unassigning ${filepath}..."

  local parent_commit="${commit_sha}^"

  # Check if file existed before assignment
  if git cat-file -e "${parent_commit}:${filepath}" 2>/dev/null; then
    # File existed - restore to previous version
    git show "${parent_commit}:${filepath}" > "${filepath}"
    git add "${filepath}"
  else
    # File didn't exist - delete it
    git rm "${filepath}" 2>/dev/null || rm -f "${filepath}"
  fi

  if true; then
    success "Unassigned '${filepath}' from '${worktree_name}'"
    info "File is now uncommitted in worktree-staging"

    # Try to remove from worktree (best effort)
    local repo_root
    repo_root=$(get_repo_root)

    local worktree_path
    worktree_path=$(get_worktree_path "$worktree_name")

    local abs_worktree_path="${repo_root}/${worktree_path}"

    if [[ -d "$abs_worktree_path" ]]; then
      if pushd "$abs_worktree_path" > /dev/null 2>&1; then
        if [[ -f "$filepath" ]]; then
          git checkout HEAD -- "$filepath" 2>/dev/null || rm -f "$filepath"
          info "Removed changes from worktree"
        fi
        popd > /dev/null 2>&1
      fi
    fi
    echo ""
    source "${WT_ROOT}/commands/status.sh"
    cmd_status
  else
    error "Failed to revert commit. There may be conflicts."
  fi
}

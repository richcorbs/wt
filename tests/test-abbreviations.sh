#!/usr/bin/env bash
# Tests for abbreviated commands

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Setup
setup_test_env

# Test: wt cr (create)
test_section "Testing: Abbreviated command 'cr' for 'create'"
REPO=$(create_test_repo "abbrev-create-test")
cd "$REPO"
$WT_BIN init > /dev/null 2>&1

assert_success "$WT_BIN cr test-wt feature/test" "wt cr should work as alias for create"
assert_file_exists ".worktrees/test-wt" "Worktree should be created with abbreviated command"

# Test: wt ls (list)
test_section "Testing: Abbreviated command 'ls' for 'list'"
LIST_OUTPUT=$($WT_BIN ls 2>&1)
assert_contains "$LIST_OUTPUT" "test-wt" "wt ls should work as alias for list"

# Test: wt st (status)
test_section "Testing: Abbreviated command 'st' for 'status'"
echo "class Admin; end" > app/models/admin.rb
STATUS_OUTPUT=$($WT_BIN st 2>&1)
assert_contains "$STATUS_OUTPUT" "Unassigned changes" "wt st should work as alias for status"
assert_contains "$STATUS_OUTPUT" "admin.rb" "wt st should show changed files"

# Test: wt as (assign)
test_section "Testing: Abbreviated command 'as' for 'assign'"
assert_success "$WT_BIN as app/models/admin.rb test-wt" "wt as should work as alias for assign"

cd .worktrees/test-wt
assert_file_exists "app/models/admin.rb" "File should be assigned with abbreviated command"
cd "$REPO"

# Test: wt cm (commit)
test_section "Testing: Abbreviated command 'cm' for 'commit'"
echo "class Post; end" > app/models/post.rb
$WT_BIN as app/models/post.rb test-wt > /dev/null 2>&1

assert_success "$WT_BIN cm test-wt 'Add post model'" "wt cm should work as alias for commit"

cd .worktrees/test-wt
LAST_COMMIT=$(git log -1 --format="%s")
assert_contains "$LAST_COMMIT" "Add post model" "Commit with abbreviated command should work"
cd "$REPO"

# Test: wt ap (apply)
test_section "Testing: Abbreviated command 'ap' for 'apply'"
assert_success "$WT_BIN ap test-wt" "wt ap should work as alias for apply"

LAST_COMMIT=$(git log -1 --format="%s")
assert_contains "$LAST_COMMIT" "Add post model" "Apply with abbreviated command should work"

# Test: wt ua (unapply)
test_section "Testing: Abbreviated command 'ua' for 'unapply'"
assert_success "$WT_BIN ua test-wt" "wt ua should work as alias for unapply"

# Test: wt un (undo)
test_section "Testing: Abbreviated command 'un' for 'undo'"
REPO=$(create_test_repo "abbrev-undo-test")
cd "$REPO"
$WT_BIN init > /dev/null 2>&1
$WT_BIN cr test-wt feature/test > /dev/null 2>&1

echo "class Admin; end" > app/models/admin.rb
$WT_BIN as app/models/admin.rb test-wt > /dev/null 2>&1
$WT_BIN cm test-wt "Add admin" > /dev/null 2>&1

assert_success "$WT_BIN un test-wt" "wt un should work as alias for undo"

cd .worktrees/test-wt
# After undo, file should be uncommitted
UNCOMMITTED=$(git status --short)
assert_contains "$UNCOMMITTED" "admin.rb" "File should be uncommitted after undo"
cd "$REPO"

# Test: wt rm (remove)
test_section "Testing: Abbreviated command 'rm' for 'remove'"
REPO=$(create_test_repo "abbrev-remove-test")
cd "$REPO"
$WT_BIN init > /dev/null 2>&1
$WT_BIN cr test-wt feature/test > /dev/null 2>&1

assert_success "$WT_BIN rm test-wt --force" "wt rm should work as alias for remove"
assert_file_not_exists ".worktrees/test-wt" "Worktree should be removed with abbreviated command"

# Test: wt sy (sync)
test_section "Testing: Abbreviated command 'sy' for 'sync'"
REPO=$(create_test_repo "abbrev-sync-test")
cd "$REPO"

# Make a change on main
echo "Main change" >> README.md
git add README.md
git commit -m "Update on main"

$WT_BIN init > /dev/null 2>&1

assert_success "$WT_BIN sy" "wt sy should work as alias for sync"

# Check sync worked
SYNC_CONTENT=$(grep "Main change" README.md || echo "")
assert_contains "$SYNC_CONTENT" "Main change" "Sync with abbreviated command should work"

# Print summary
print_test_summary

# Exit with appropriate code
exit $TEST_FAILED

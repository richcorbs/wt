#!/usr/bin/env bash
# Tests for wt stage command

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Setup
setup_test_env

# Test: wt stage (single file)
test_section "Testing: wt stage (single file)"
REPO=$(create_test_repo "stage-single-test")
cd "$REPO"
$WT_BIN init > /dev/null 2>&1
$WT_BIN create test-wt feature/test > /dev/null 2>&1

# Make changes and assign
echo "class Admin; end" > app/models/admin.rb
echo "class Post; end" > app/models/post.rb
$WT_BIN assign app/models/admin.rb test-wt > /dev/null 2>&1
$WT_BIN assign app/models/post.rb test-wt > /dev/null 2>&1

# Stage single file
assert_success "$WT_BIN stage test-wt app/models/admin.rb" "wt stage single file should succeed"

# Check that file is staged in worktree
cd .worktrees/test-wt
STAGED_FILES=$(git diff --name-only --cached)
assert_contains "$STAGED_FILES" "admin.rb" "admin.rb should be staged"

# Check that other file is not staged
UNSTAGED_FILES=$(git diff --name-only)
assert_contains "$UNSTAGED_FILES" "post.rb" "post.rb should remain unstaged"
cd "$REPO"

# Test: wt stage (directory)
test_section "Testing: wt stage (directory)"
REPO=$(create_test_repo "stage-dir-test")
cd "$REPO"
$WT_BIN init > /dev/null 2>&1
$WT_BIN create test-wt feature/test > /dev/null 2>&1

# Make changes and assign
echo "class Admin; end" > app/models/admin.rb
echo "class Post; end" > app/models/post.rb
echo "Updated" >> app/controllers/posts_controller.rb
$WT_BIN assign app/models/ test-wt > /dev/null 2>&1
$WT_BIN assign app/controllers/posts_controller.rb test-wt > /dev/null 2>&1

# Stage directory
assert_success "$WT_BIN stage test-wt app/models/" "wt stage directory should succeed"

# Check that directory files are staged
cd .worktrees/test-wt
STAGED_FILES=$(git diff --name-only --cached)
assert_contains "$STAGED_FILES" "admin.rb" "admin.rb should be staged"
assert_contains "$STAGED_FILES" "post.rb" "post.rb should be staged"

# Check that controller is not staged
UNSTAGED_FILES=$(git diff --name-only)
assert_contains "$UNSTAGED_FILES" "posts_controller.rb" "posts_controller.rb should remain unstaged"
cd "$REPO"

# Test: wt stage (all files)
test_section "Testing: wt stage (all files)"
REPO=$(create_test_repo "stage-all-test")
cd "$REPO"
$WT_BIN init > /dev/null 2>&1
$WT_BIN create test-wt feature/test > /dev/null 2>&1

# Make changes and assign
echo "class Admin; end" > app/models/admin.rb
echo "Updated" >> app/controllers/posts_controller.rb
$WT_BIN assign app/models/admin.rb test-wt > /dev/null 2>&1
$WT_BIN assign app/controllers/posts_controller.rb test-wt > /dev/null 2>&1

# Stage all
assert_success "$WT_BIN stage test-wt '*'" "wt stage all should succeed"

# Check that all files are staged
cd .worktrees/test-wt
STAGED_FILES=$(git diff --name-only --cached)
assert_contains "$STAGED_FILES" "admin.rb" "admin.rb should be staged"
assert_contains "$STAGED_FILES" "posts_controller.rb" "posts_controller.rb should be staged"

# Check that nothing is unstaged
UNSTAGED_COUNT=$(git diff --name-only | wc -l | tr -d ' ')
assert_success "[[ $UNSTAGED_COUNT -eq 0 ]]" "All files should be staged"
cd "$REPO"

# Test: wt commit with staged files
test_section "Testing: wt commit with selective staging"
REPO=$(create_test_repo "commit-staged-test")
cd "$REPO"
$WT_BIN init > /dev/null 2>&1
$WT_BIN create test-wt feature/test > /dev/null 2>&1

# Make changes and assign
echo "class Admin; end" > app/models/admin.rb
echo "class Post; end" > app/models/post.rb
$WT_BIN assign app/models/admin.rb test-wt > /dev/null 2>&1
$WT_BIN assign app/models/post.rb test-wt > /dev/null 2>&1

# Stage only admin.rb
$WT_BIN stage test-wt app/models/admin.rb > /dev/null 2>&1

# Commit should only commit staged file
assert_success "$WT_BIN commit test-wt 'Add admin model'" "wt commit with staged files should succeed"

# Check that only admin.rb was committed
cd .worktrees/test-wt
LAST_COMMIT_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD)
assert_contains "$LAST_COMMIT_FILES" "admin.rb" "admin.rb should be in commit"

# Check that post.rb is still unstaged
UNSTAGED_FILES=$(git diff --name-only)
assert_contains "$UNSTAGED_FILES" "post.rb" "post.rb should still be unstaged"
cd "$REPO"

# Print summary
print_test_summary

# Exit with appropriate code
exit $TEST_FAILED

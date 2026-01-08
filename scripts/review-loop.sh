#!/bin/bash

set -e

# Configuration
PR_NUMBER="${1}"
REPO="${2:-$GITHUB_REPOSITORY}"
POLL_INTERVAL="${3:-30}"
TIMEOUT_SECONDS="${4:-3600}"  # 1 hour default timeout

# Bot usernames
COPILOT_BOT="github-copilot[bot]"
CODEX_BOT="codex"

# Tracking variables
LAST_COMMENT_ID=""
LAST_COMMIT_SHA=""
LOOP_COUNT=0

echo "========================================="
echo "Starting Auto-Review Loop"
echo "========================================="
echo "PR Number: ${PR_NUMBER}"
echo "Repository: ${REPO}"
echo "Poll Interval: ${POLL_INTERVAL}s"
echo "Timeout: ${TIMEOUT_SECONDS}s"
echo "========================================="

# Function to check if PR is merged
check_pr_status() {
    local state=$(gh pr view "${PR_NUMBER}" --repo "${REPO}" --json state --jq '.state')
    if [ "${state}" = "MERGED" ]; then
        echo "✓ PR is already merged. Exiting gracefully."
        exit 0
    fi
}

# Function to get the latest comment
get_latest_comment() {
    gh pr view "${PR_NUMBER}" --repo "${REPO}" --json comments --jq '.comments[-1] | {id: .id, author: .author.login, body: .body}'
}

# Function to get the latest commit SHA
get_latest_commit() {
    gh pr view "${PR_NUMBER}" --repo "${REPO}" --json commits --jq '.commits[-1].oid'
}

# Function to post a comment
post_comment() {
    local message="${1}"
    echo "📝 Posting comment: ${message}"
    gh pr comment "${PR_NUMBER}" --repo "${REPO}" --body "${message}"
}

# Function to check if response contains approval
is_approved() {
    local response="${1}"
    local lower_response=$(echo "${response}" | tr '[:upper:]' '[:lower:]')
    
    # First check for explicit approval phrases (these override issue detection)
    if echo "${lower_response}" | grep -qE "(no issues|lgtm|looks good to me|ready to merge|ship it)"; then
        echo "  → Detected explicit approval phrase"
        return 0
    fi
    
    # Check for general approval indicators
    local approval_words=("approve" "approved")
    local has_approval=false
    for word in "${approval_words[@]}"; do
        if echo "${lower_response}" | grep -q "${word}"; then
            has_approval=true
            break
        fi
    done
    
    # Check for issue indicators (but not in "no issues" context)
    local issue_patterns=("there.*issue" "found.*issue" "has.*issue" "problem" "bug" "must fix" "should fix" "need.*fix" "concern" "error")
    local has_issues=false
    for pattern in "${issue_patterns[@]}"; do
        if echo "${lower_response}" | grep -qE "${pattern}"; then
            has_issues=true
            echo "  → Detected issue indicator: ${pattern}"
            break
        fi
    done
    
    # Approved only if has approval words and no issue indicators
    if [ "${has_approval}" = true ] && [ "${has_issues}" = false ]; then
        echo "  → Approval detected"
        return 0  # true - approved
    else
        echo "  → Not approved (has_approval=${has_approval}, has_issues=${has_issues})"
        return 1  # false - not approved
    fi
}

# Function to wait for a comment from a specific user
wait_for_comment_from() {
    local expected_author="${1}"
    local timeout_msg="${2}"
    local start_time=$(date +%s)
    
    echo "⏳ Waiting for comment from ${expected_author}..."
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ ${elapsed} -gt ${TIMEOUT_SECONDS} ]; then
            echo "❌ ERROR: Timeout waiting for ${expected_author}. ${timeout_msg}"
            exit 1
        fi
        
        check_pr_status
        
        local comment_json=$(get_latest_comment)
        local comment_id=$(echo "${comment_json}" | jq -r '.id')
        local comment_author=$(echo "${comment_json}" | jq -r '.author')
        local comment_body=$(echo "${comment_json}" | jq -r '.body')
        
        # Skip if it's the same comment we've already processed
        if [ "${comment_id}" = "${LAST_COMMENT_ID}" ]; then
            echo "  [${elapsed}s] No new comments yet..."
            sleep ${POLL_INTERVAL}
            continue
        fi
        
        # Check if comment is from the expected author
        if [ "${comment_author}" = "${expected_author}" ]; then
            LAST_COMMENT_ID="${comment_id}"
            echo "✓ New comment from ${expected_author} (ID: ${comment_id})"
            echo "  Comment: ${comment_body}"
            echo "${comment_body}"
            return 0
        fi
        
        echo "  [${elapsed}s] Comment from ${comment_author}, waiting for ${expected_author}..."
        LAST_COMMENT_ID="${comment_id}"
        sleep ${POLL_INTERVAL}
    done
}

# Function to wait for new commits
wait_for_new_commits() {
    local start_time=$(date +%s)
    
    echo "⏳ Waiting for Copilot to push new commits..."
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ ${elapsed} -gt ${TIMEOUT_SECONDS} ]; then
            echo "❌ ERROR: Timeout waiting for new commits from Copilot."
            exit 1
        fi
        
        check_pr_status
        
        local current_commit=$(get_latest_commit)
        
        if [ "${current_commit}" != "${LAST_COMMIT_SHA}" ]; then
            echo "✓ New commit detected: ${current_commit}"
            LAST_COMMIT_SHA="${current_commit}"
            return 0
        fi
        
        echo "  [${elapsed}s] No new commits yet (still at ${LAST_COMMIT_SHA})..."
        sleep ${POLL_INTERVAL}
    done
}

# Main loop
echo ""
echo "Initializing tracking..."
LAST_COMMIT_SHA=$(get_latest_commit)
echo "Initial commit SHA: ${LAST_COMMIT_SHA}"

# Get the last comment ID to avoid reprocessing
existing_comment=$(get_latest_comment)
LAST_COMMENT_ID=$(echo "${existing_comment}" | jq -r '.id')
echo "Last comment ID: ${LAST_COMMENT_ID}"
echo ""

# Main review loop
while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))
    echo "========================================="
    echo "Review Loop Iteration #${LOOP_COUNT}"
    echo "========================================="
    
    check_pr_status
    
    # Step 1: Request review from Codex
    post_comment "@${CODEX_BOT} review"
    
    # Step 2: Wait for Codex response
    codex_response=$(wait_for_comment_from "${CODEX_BOT}" "Codex did not respond to review request.")
    
    # Step 3: Parse Codex response
    echo ""
    echo "Analyzing Codex response..."
    if is_approved "${codex_response}"; then
        echo "✓ Codex APPROVED the PR!"
        echo ""
        echo "========================================="
        echo "Merging PR..."
        echo "========================================="
        
        # Enable auto-merge with squash
        gh pr merge "${PR_NUMBER}" --repo "${REPO}" --auto --squash
        
        echo "✓ Auto-merge enabled. PR will be merged automatically once all checks pass."
        echo ""
        echo "========================================="
        echo "Review loop completed successfully!"
        echo "========================================="
        exit 0
    else
        echo "⚠ Codex found issues that need to be addressed."
        echo ""
        
        # Step 4: Ask Copilot to address feedback
        post_comment "@${COPILOT_BOT} address that feedback"
        
        # Step 5: Wait for Copilot to push new commits
        wait_for_new_commits
        
        echo ""
        echo "Copilot has pushed updates. Starting next review iteration..."
        echo ""
        
        # Brief pause before next iteration
        sleep 5
    fi
done

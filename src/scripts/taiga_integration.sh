#!/bin/bash
set -e

command -v backlogr >/dev/null 2>&1 || {
  echo >&2 "❌ backlogr is required but it's not installed. Aborting."
  exit 1
}

COMMIT_MSG=$(git log -1 --pretty=%B)
echo "🔍 Parsing commit message: $COMMIT_MSG"

# Parse commit message format: <mod>: <message> (#<id>)
if [[ "$COMMIT_MSG" =~ ^([^:]+):[[:space:]]*(.+)[[:space:]]*\(#([0-9]+)\)$ ]]; then
    MOD="${BASH_REMATCH[1]}"
    MESSAGE="${BASH_REMATCH[2]}"
    TASK_ID="${BASH_REMATCH[3]}"
    echo "✅ Extracted from commit:"
    echo "   - Modifier: $MOD"
    echo "   - Message: $MESSAGE"
    echo "   - Task ID: $TASK_ID"
else
    echo "❌ Invalid commit format detected."
    echo "ℹ️ Expected format: <mod>: <message> (#<id>)"
    echo "ℹ️ Examples:"
    echo "   feat: add user authentication (#123)"
    echo "   fix: resolve login bug (#456)"
    echo "   done: complete user profile feature (#789)"
    exit 0
fi

USERNAME="${TAIGA_USERNAME:-}"
PASSWORD="${TAIGA_PASSWORD:-}"
PROJECT_NAME="${PROJECT_NAME:-}"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$PROJECT_NAME" ]; then
    echo "❌ Environment variables TAIGA_USERNAME, TAIGA_PASSWORD and PROJECT_NAME must be set."
    exit 1
fi

# Determine backlogr command based on modifier
case "${MOD,,}" in 
    "feat"|"feature"|"add"|"implement")
        COMMAND="wip"
        ACTION_DESC="Moving task to 'In Progress'"
        ;;
    "fix"|"bugfix"|"patch"|"hotfix")
        COMMAND="wip"
        ACTION_DESC="Moving task to 'In Progress' (fixing)"
        ;;
    "done"|"complete"|"finish"|"resolve")
        COMMAND="done"
        ACTION_DESC="Moving task to 'Done'"
        ;;
    "delete"|"remove"|"cancel"|"drop")
        COMMAND="delete"
        ACTION_DESC="Deleting task"
        ;;
    "wip"|"progress"|"start"|"begin")
        COMMAND="wip"
        ACTION_DESC="Moving task to 'In Progress'"
        ;;
    *)
        echo "⚠️ Unknown modifier '$MOD'. Supported modifiers:"
        echo "   - feat, feature, add, implement → moves to WIP"
        echo "   - fix, bugfix, patch, hotfix → moves to WIP"
        echo "   - done, complete, finish, resolve → moves to Done"
        echo "   - delete, remove, cancel, drop → deletes task"
        echo "   - wip, progress, start, begin → moves to WIP"
        echo "ℹ️ No action will be taken."
        exit 0
        ;;
esac

echo "🚀 $ACTION_DESC for task #$TASK_ID..."

# Execute backlogr command
if backlogr --username "$USERNAME" --password "$PASSWORD" --project_name "$PROJECT_NAME" "$COMMAND" "$TASK_ID"; then
    echo "✅ Successfully executed: $ACTION_DESC"
    echo "📝 Commit message: $MESSAGE"
else
    echo "❌ Failed to execute backlogr command"
    exit 1
fi

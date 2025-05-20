#!/bin/bash
set -e

TAIGA_API_URL=${TAIGA_API_URL:-https://api.taiga.io/api/v1}
PROJECT_NAME="${PROJECT_NAME:-}"

command -v jq >/dev/null 2>&1 || {
  echo >&2 "❌ jq is required but it's not installed. Aborting."
  exit 1
}

COMMIT_MSG=$(git log -1 --pretty=%B)
echo "🔍 Parsing commit message: $COMMIT_MSG"

if [[ "$COMMIT_MSG" =~ \[task#([0-9]+)\]$ ]]; then
    TASK_ID="${BASH_REMATCH[1]}"
    echo "✅ Extracted Task ID from commit message: $TASK_ID"
else
    echo "❌ Invalid commit format detected."
    echo "ℹ️ Expected format: feat: <message> [task#<id>]"
    exit 0
fi

USERNAME="${TAIGA_USERNAME:-}"
PASSWORD="${TAIGA_PASSWORD:-}"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "❌ Environment variables TAIGA_USERNAME and TAIGA_PASSWORD must be set."
    exit 1
fi

echo "🔐 Authenticating with Taiga API..."

DATA=$(jq --null-input \
        --arg username "$USERNAME" \
        --arg password "$PASSWORD" \
        '{ type: "normal", username: $username, password: $password }')

USER_AUTH_DETAIL=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$DATA" \
  "$TAIGA_API_URL/auth")

AUTH_TOKEN=$(echo "$USER_AUTH_DETAIL" | jq -r '.auth_token')

if [ -z "$AUTH_TOKEN" ] || [ "$AUTH_TOKEN" == "null" ]; then
    echo "❌ Authentication failed. Please check your username and password."
    exit 1
fi

echo "✅ Successfully authenticated with Taiga."

echo "📋 Fetching your user info..."

USER_ID=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$TAIGA_API_URL/users/me" | jq -r '.id')

if [ -z "$USER_ID" ] || [ "$USER_ID" == "null" ]; then
    echo "❌ Failed to retrieve user ID."
    exit 1
fi

echo "✅ Your Taiga user ID is: $USER_ID"

echo "🔎 Searching for project named '$PROJECT_NAME' where you are a member..."

PROJECT_ID=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" \
  "$TAIGA_API_URL/projects?member=$USER_ID" \
  | jq -r --arg name "$PROJECT_NAME" '.[] | select(.name == $name) | .id')

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Could not find a project named '$PROJECT_NAME'. Please check the project name."
  exit 1
fi

echo "✅ Found project ID: $PROJECT_ID for project '$PROJECT_NAME'"

echo "🔍 Looking up user story with ref #$TASK_ID in project..."

USER_STORY_ID=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" \
  "$TAIGA_API_URL/userstories?project=$PROJECT_ID" \
  | jq -r --arg task_id "$TASK_ID" '.[] | select(.ref == ($task_id | tonumber)) | .id')

if [ -z "$USER_STORY_ID" ]; then
    echo "❌ User story with ref #$TASK_ID not found in project '$PROJECT_NAME'."
    exit 1
fi

echo "✅ Found user story ID: $USER_STORY_ID"

echo "🔍 Fetching 'Done' status ID for the project..."

DONE_STATUS_ID=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" \
  "$TAIGA_API_URL/userstory-statuses?project=$PROJECT_ID" \
  | jq -r '.[] | select(.name == "Done") | .id')

if [ -z "$DONE_STATUS_ID" ] || [ "$DONE_STATUS_ID" == "null" ]; then
    echo "❌ Could not find a 'Done' status for project '$PROJECT_NAME'."
    exit 1
fi

echo "✅ 'Done' status ID is: $DONE_STATUS_ID"

echo "🔍 Retrieving current version of user story #$TASK_ID..."

USER_STORY_DETAIL=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" \
  "$TAIGA_API_URL/userstories/$USER_STORY_ID")

CURRENT_VERSION=$(echo "$USER_STORY_DETAIL" | jq -r '.version')

if [ -z "$CURRENT_VERSION" ] || [ "$CURRENT_VERSION" == "null" ]; then
    echo "❌ Could not fetch current version for user story ID $USER_STORY_ID"
    exit 1
fi

echo "✅ Current version of user story #$TASK_ID is $CURRENT_VERSION"

echo "🔄 Updating user story status to 'Done'..."

PATCH_DATA=$(jq --null-input \
  --argjson status "$DONE_STATUS_ID" \
  --argjson version "$CURRENT_VERSION" \
  '{ status: $status, version: $version }')

curl -s -X PATCH \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "$PATCH_DATA" \
  "$TAIGA_API_URL/userstories/$USER_STORY_ID" > /dev/null

echo "✅ Successfully updated user story #$TASK_ID to 'Done' (version $CURRENT_VERSION)"

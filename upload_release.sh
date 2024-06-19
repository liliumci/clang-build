#!/bin/bash

# Check if all required arguments are provided
if [ $# -ne 5 ]; then
    echo "Usage: $0 <release_tag> <github_token> <repository_owner> <repository_name> <file_to_upload>"
    exit 1
fi

RELEASE_TAG=$1
GITHUB_TOKEN=$2
REPO_OWNER=$3
REPO_NAME=$4
FILE_TO_UPLOAD=$5

# Create a new release
response=$(curl -X POST -H "Authorization: token $GITHUB_TOKEN" -d "{\"tag_name\": \"$RELEASE_TAG\", \"name\": \"$RELEASE_TAG\", \"draft\": false, \"prerelease\": false}" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases")

# Extract the release ID
release_id=$(echo $response | jq '.id')

# Upload file to the release
upload_url=$(echo $response | jq -r '.upload_url' | sed -e "s/{?name,label}//")

curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$FILE_TO_UPLOAD" \
  "$upload_url?name=$(basename $FILE_TO_UPLOAD)"

echo "File $FILE_TO_UPLOAD uploaded to release $RELEASE_TAG in repository $REPO_OWNER/$REPO_NAME"
#!/bin/bash

# remove-k8s-from-git.sh
# This script deletes the ./k8s directory and permanently removes it from Git history.

set -e

DIR_TO_REMOVE="k8s"

# Check if we are in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: This script must be run inside a Git repository."
    exit 1
fi

echo "--- Permanent removal of '$DIR_TO_REMOVE' from Git history ---"

# 1. Remove the directory from the current working tree
if [ -d "$DIR_TO_REMOVE" ]; then
    echo "Removing '$DIR_TO_REMOVE' from the local filesystem..."
    rm -rf "$DIR_TO_REMOVE"
fi

# 2. Use git filter-branch to remove the directory from all commits
# We use --index-filter for speed as it doesn't check out each commit
echo "Purging '$DIR_TO_REMOVE' from all branches in history..."
echo "This may take a while depending on the size of the repository."

git filter-branch --force --index-filter \
    "git rm -r --cached --ignore-unmatch $DIR_TO_REMOVE" \
    --prune-empty --tag-name-filter cat -- --all

# 3. Cleanup and reclaim space
echo "Cleaning up git internal references and reclaiming space..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 4. Update .gitignore to ensure it's not added back
if ! grep -q "^$DIR_TO_REMOVE/" .gitignore 2>/dev/null; then
    echo "Updating .gitignore..."
    echo "$DIR_TO_REMOVE/" >> .gitignore
fi

echo "--- SUCCESS ---"
echo "The directory '$DIR_TO_REMOVE' has been removed from the current state and all history."
echo ""
echo "IMPORTANT: If you have a remote repository, you must force push to update it:"
echo "git push origin --force --all"
echo "git push origin --force --tags"
echo ""
echo "Warning: Force pushing will overwrite the history on the remote. Ensure all collaborators are informed."

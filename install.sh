#!/usr/bin/env bash
#
# Install (or update) all mx-harness skills into your agent's global skill directory.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/maxence2997/mx-harness/main/install.sh | bash
#
# Or after cloning:
#   ./install.sh
#
# Requires: Node.js (for npx).

set -euo pipefail

REPO="https://github.com/maxence2997/mx-harness"
SKILLS=(
  mx-flow
  mx-brainstorm
  mx-team-review
  mx-review-triage
  mx-commit
  mx-pr
  mx-status
)

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx not found. Install Node.js from https://nodejs.org/" >&2
  exit 1
fi

echo "Installing ${#SKILLS[@]} mx-harness skills from $REPO"
echo

failed=()
for skill in "${SKILLS[@]}"; do
  echo "==> $skill"
  if ! npx -y skills add "$REPO" --skill "$skill" -g -y; then
    failed+=("$skill")
  fi
  echo
done

if [ ${#failed[@]} -eq 0 ]; then
  echo "Done. All ${#SKILLS[@]} skills installed."
else
  echo "Done with ${#failed[@]} failure(s): ${failed[*]}"
  exit 1
fi

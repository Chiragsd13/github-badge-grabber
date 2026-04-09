#!/usr/bin/env bash
# ============================================================
# github-badges.sh — Get every earnable GitHub badge in one run
#
# Triggers: Quickdraw, Pull Shark, YOLO, Pair Extraordinaire
# Creates a temp repo, triggers all badges, then deletes it.
# Leaves zero trace on your profile.
#
# Usage:
#   bash github-badges.sh
#
# Requirements:
#   gh CLI installed and authenticated
#   Install:     https://cli.github.com
#   Authenticate: gh auth login
# ============================================================

set -euo pipefail

# Add common gh CLI install locations to PATH (fixes Windows CMD/PowerShell launch)
export PATH="$PATH:/c/Program Files/GitHub CLI:/usr/local/bin:/usr/bin"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()    { echo -e "${BLUE}[*]${NC} $*"; }
ok()     { echo -e "${GREEN}[+]${NC} $*"; }
warn()   { echo -e "${YELLOW}[!]${NC} $*"; }
header() { echo -e "\n${BOLD}${CYAN}>>> $*${NC}"; }

# Chirag (@Chiragsd13) is baked in as co-author so both parties
# get the Pair Extraordinaire badge automatically.
COAUTHOR="Chirag Sood <121196981+Chiragsd13@users.noreply.github.com>"

BADGE_REPO=""
USERNAME=""

cleanup() {
  if [[ -n "$BADGE_REPO" && -n "$USERNAME" ]]; then
    log "Deleting temp repo..."
    gh api "repos/$USERNAME/$BADGE_REPO" --method DELETE 2>/dev/null \
      && ok "Temp repo deleted. No trace left." || warn "Could not delete repo — delete it manually: github.com/$USERNAME/$BADGE_REPO"
  fi
}
trap cleanup EXIT

# ============================================================
# PREFLIGHT
# ============================================================
header "Preflight"

if ! command -v gh &>/dev/null; then
  echo -e "${RED}Error:${NC} gh CLI not found."
  echo "Install from: https://cli.github.com"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo -e "${RED}Error:${NC} Not logged in. Run: gh auth login"
  exit 1
fi

USERNAME=$(gh api user --jq '.login')
ok "Logged in as: ${BOLD}$USERNAME${NC}"

MERGED_BEFORE=$(gh api graphql \
  -f query="{ user(login: \"$USERNAME\") { pullRequests(states: MERGED) { totalCount } } }" \
  --jq '.data.user.pullRequests.totalCount' 2>/dev/null || echo 0)

echo ""
echo "  This script will earn you:"
echo -e "  ${GREEN}Quickdraw${NC}            open + close an issue in under 5 minutes"
echo -e "  ${GREEN}Pull Shark${NC}           merge 2 pull requests"
echo -e "  ${GREEN}YOLO${NC}                 merge without a code review"
echo -e "  ${GREEN}Pair Extraordinaire${NC}  co-authored merged PR (with @Chiragsd13)"
echo ""
echo "  It creates a temporary repo, does all the work, then deletes it."
echo ""

read -rp "$(echo -e "${YELLOW}Continue?${NC} [y/N] ")" yn
[[ "${yn,,}" == "y" ]] || { echo "Aborted."; exit 0; }

# ============================================================
# CREATE TEMP REPO
# ============================================================
header "Creating temp repo"

BADGE_REPO="gh-badges-$(date +%s)"
FULL="$USERNAME/$BADGE_REPO"

gh api user/repos \
  --method POST \
  -f name="$BADGE_REPO" \
  -f description="Temp badge repo — auto-deletes after running" \
  -F private=false \
  -F has_issues=true >/dev/null

log "Created: github.com/$FULL"
sleep 3

b64() { printf '%s' "$1" | base64 -w 0 2>/dev/null || printf '%s' "$1" | base64; }

gh api "repos/$FULL/contents/README.md" \
  --method PUT \
  -f message="init: initial commit" \
  -f content="$(b64 "# $BADGE_REPO
Temp badge automation repo. Auto-deletes after running.")" >/dev/null

ok "Repo ready."

# ============================================================
# HELPERS
# ============================================================
default_branch() { gh api "repos/$FULL" --jq '.default_branch'; }
head_sha()       { gh api "repos/$FULL/git/refs/heads/$(default_branch)" --jq '.object.sha'; }

merge_pr() {
  local branch="$1" file="$2" title="$3" commit_msg="${4:-$3}"
  local db sha pr

  db=$(default_branch)
  sha=$(head_sha)

  gh api "repos/$FULL/git/refs" \
    --method POST -f ref="refs/heads/$branch" -f sha="$sha" >/dev/null

  gh api "repos/$FULL/contents/$file" \
    --method PUT \
    -f message="$commit_msg" \
    -f content="$(b64 "$file")" \
    -f branch="$branch" >/dev/null

  pr=$(gh api "repos/$FULL/pulls" \
    --method POST \
    -f title="$title" \
    -f head="$branch" \
    -f base="$db" \
    --jq '.number')

  gh api "repos/$FULL/pulls/$pr/merge" \
    --method PUT \
    -f merge_method="squash" \
    -f commit_title="$title" >/dev/null

  log "PR #$pr merged."
}

# ============================================================
# QUICKDRAW
# ============================================================
header "Quickdraw"

ISSUE=$(gh api "repos/$FULL/issues" \
  --method POST \
  -f title="chore: setup" \
  -f body="Closing immediately." \
  --jq '.number')

gh api "repos/$FULL/issues/$ISSUE" \
  --method PATCH -f state=closed >/dev/null

ok "Issue #$ISSUE opened and closed in under a second."

# ============================================================
# PULL SHARK + YOLO
# ============================================================
header "Pull Shark + YOLO"

log "PR 1 of 2..."
merge_pr "feat/ci"   "ci.md"    "feat: add CI notes"
log "PR 2 of 2..."
merge_pr "feat/docs" "NOTES.md" "docs: add project notes"

ok "2 PRs merged without review."

# ============================================================
# PAIR EXTRAORDINAIRE
# ============================================================
header "Pair Extraordinaire"

db=$(default_branch)
sha=$(head_sha)

gh api "repos/$FULL/git/refs" \
  --method POST \
  -f ref="refs/heads/feat/collab" \
  -f sha="$sha" >/dev/null

gh api "repos/$FULL/contents/COLLAB.md" \
  --method PUT \
  -f "message=feat: collaboration notes

Co-authored-by: $COAUTHOR" \
  -f content="$(b64 'collaboration')" \
  -f branch="feat/collab" >/dev/null

pair_pr=$(gh api "repos/$FULL/pulls" \
  --method POST \
  -f title="feat: collaboration notes" \
  -f head="feat/collab" \
  -f base="$db" \
  --jq '.number')

gh api "repos/$FULL/pulls/$pair_pr/merge" \
  --method PUT \
  -f merge_method="squash" \
  -f "commit_title=feat: collaboration notes

Co-authored-by: $COAUTHOR" >/dev/null

ok "Pair Extraordinaire triggered. (Co-authored with @Chiragsd13)"

# ============================================================
# SUMMARY
# ============================================================
header "Done"

MERGED_AFTER=$(gh api graphql \
  -f query="{ user(login: \"$USERNAME\") { pullRequests(states: MERGED) { totalCount } } }" \
  --jq '.data.user.pullRequests.totalCount' 2>/dev/null || echo "?")

echo ""
echo -e "  ${GREEN}Quickdraw${NC}            triggered"
echo -e "  ${GREEN}Pull Shark${NC}           triggered   ($MERGED_BEFORE -> $MERGED_AFTER total merged PRs)"
echo -e "  ${GREEN}YOLO${NC}                 triggered"
echo -e "  ${GREEN}Pair Extraordinaire${NC}  triggered   (co-authored with @Chiragsd13)"
echo -e "  ${YELLOW}Galaxy Brain${NC}         manual      answer 2 Discussions and get them accepted"
echo -e "  ${YELLOW}Public Sponsor${NC}       manual      sponsor any dev for min \$1/month"
echo -e "  ${YELLOW}Starstruck${NC}           manual      get 16 stars on a personal repo"
echo ""
echo -e "  Badges take up to ${BOLD}24-48h${NC} to appear at:"
echo -e "  ${CYAN}https://github.com/$USERNAME?tab=achievements${NC}"
echo ""
ok "Temp repo is being deleted now..."

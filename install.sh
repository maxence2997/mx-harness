#!/usr/bin/env bash
#
# Install or update the mx-harness skills for every supported agent on this machine.
#
# Usage:
#   curl -fsSL --retry 3 https://github.com/maxence2997/mx-harness/archive/refs/heads/main.tar.gz | tar -xz -C /tmp && bash /tmp/mx-harness-main/install.sh --ref vX.Y.Z
#   ./install.sh [skill ...]   # from a clone: installs the working tree; optional subset
#   ./install.sh --remote      # ignore the local tree, fetch GitHub main instead
#   ./install.sh --ref v1.2.0  # fetch that release tag instead (implies --remote)
#   ./install.sh --prune       # also remove skills this repo no longer ships
#   ~/.mx/.mx-harness-install.sh --auto-update   # what every skill runs first
#
# Only --ref installs update themselves (README "Automatic updates");
# working-tree and main installs stay as installed.
#
# Layout (one copy, many links):
#   ~/.agents/skills/<skill>/            canonical copy — Codex reads it directly
#   ~/.claude/skills/<skill> -> canonical   symlink; likewise ~/.codex, ~/.cursor,
#                                        ~/.copilot, for each agent home that exists
#
# Lock: ~/.mx/.mx-harness.lock, tab-separated rows
#   <skill>  root      <canonical dir>
#   <skill>  <file>    <sha256 of that file as this script last wrote it>
#   _meta    source    <commit sha, or the local path installed from>
#   _meta    version   <vX.Y.Z tag, git describe output, "main", or "unknown">
#
# Update rules:
#   - SKILL.md and README.md are always overwritten (canonical from the repo).
#   - references/* are overwritten only if unchanged since this script last
#     wrote them — local edits are preserved.
#   - Existing skill symlinks are backed up and linked to canonical; their
#     checkout targets are never updated through the old links.
#   - A real directory at an agent path (installs before 2026-09-11) seeds the
#     canonical copy after reference conflicts are checked, then is moved to
#     ~/.mx/backups/ and replaced by a symlink.
#     Real directories are never deleted, only moved there; stale symlinks
#     (dangling, or pointing at a retired skill) are removed in place.
#   - A fully successful run also copies the source's install.sh to
#     ~/.mx/.mx-harness-install.sh, which every skill runs with --auto-update.
#
# Requires: bash 3.2+ (macOS default). curl and tar only for --remote, or when
# the script is not sitting next to the skill directories. The tarball comes
# from codeload.github.com on purpose: raw.githubusercontent.com rate-limits
# per IP and 429s on shared/corporate networks.

set -euo pipefail

REPO="https://github.com/maxence2997/mx-harness"
LOCK="$HOME/.mx/.mx-harness.lock"
BACKUP_ROOT="$HOME/.mx/backups"
CANON_BASE="$HOME/.agents/skills"
SKILLS=(mx-doctrine mx-flow mx-brainstorm mx-team-review mx-review-triage mx-commit mx-pr)
# <home>/skills/<skill> becomes a symlink to the canonical copy when <home> exists.
AGENT_HOMES=(
  "$HOME/.claude"   # Claude Code
  "$HOME/.config/claude" # Legacy Claude Code XDG installation
  "$HOME/.codex"    # Codex — legacy path, kept for versions that predate ~/.agents/skills
  "$HOME/.cursor"   # Cursor
  "$HOME/.copilot"  # GitHub Copilot
)

# --- helpers ---

usage() {
  cat <<EOF
Usage: install.sh [--remote | --ref vX.Y.Z] [--prune] [skill ...]
       install.sh --auto-update

Installs or updates mx-harness skills: one canonical copy per skill under
~/.agents/skills, symlinked from ~/.claude/skills, ~/.codex/skills,
~/.cursor/skills and ~/.copilot/skills (whichever agent homes exist).

  --remote   fetch GitHub main instead of installing from this checkout/tarball
  --ref TAG  fetch release tag TAG (vX.Y.Z) from GitHub instead; only these
             installs update themselves before each skill run
  --prune    remove skills this repo no longer ships (moved to ~/.mx/backups first)
  skill ...  install only these; default is all: ${SKILLS[*]}
  --auto-update
             move a --ref install to the newest release of its major version;
             every skill runs this first; prints only news, always exits 0
EOF
}

die() { echo "error: $*" >&2; exit 1; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Physical path of a directory, following symlinks; empty if it does not resolve.
realdir() { (cd "$1" 2>/dev/null && pwd -P) || true; }

in_list() {
  local x=$1 y; shift
  for y in "$@"; do [[ "$x" == "$y" ]] && return 0; done
  return 1
}

lock_get() {
  grep -m1 "^${1}	${2}	" "$LOCK" 2>/dev/null | cut -f3- || true
}

lock_set() {
  touch "$LOCK"
  local tmp; tmp=$(mktemp)
  grep -v "^${1}	${2}	" "$LOCK" > "$tmp" || true
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$tmp"
  mv "$tmp" "$LOCK"
}

lock_del_skill() {
  [[ -f "$LOCK" ]] || return 0
  local tmp; tmp=$(mktemp)
  grep -v "^${1}	" "$LOCK" > "$tmp" || true
  mv "$tmp" "$LOCK"
}

# Skills the lock knows about (one per line).
lock_skills() {
  [[ -f "$LOCK" ]] && awk -F'\t' '$2=="root"{print $1}' "$LOCK" || true
}

BACKUP_DIR=""
# Move a path into this run's backup directory instead of deleting it.
move_to_backup() {
  local path=$1 label
  # ~/.codex/skills/mx-pr -> codex_skills_mx-pr (no leading dot, so ls shows it)
  label=$(printf '%s' "${path#$HOME/}" | tr '/' '_' | sed 's/^\.//')
  if [[ -z "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_ROOT" || return 1
    BACKUP_DIR=$(mktemp -d "$BACKUP_ROOT/install-$(date +%Y%m%d-%H%M%S)-XXXXXX") || return 1
  fi
  mkdir -p "$BACKUP_DIR" || return 1
  mv "$path" "$BACKUP_DIR/$label" || return 1
  echo "  ↳ moved $path to $BACKUP_DIR/$label"
}

# --- source ---

SRC=""
LOCAL_SOURCE_ROOT=""
SOURCE_ID=""
VERSION_ID=""
TMP=""

fetch_remote() {
  local url label d
  if [[ -n "$REF" ]]; then
    url="$REPO/archive/refs/tags/$REF.tar.gz"; label=$REF
  else
    url="$REPO/archive/refs/heads/main.tar.gz"; label=main
  fi
  command -v curl >/dev/null 2>&1 || die "curl not found (needed to fetch $REPO)"
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  echo "Fetching $REPO $label..."
  # Timeouts bound a stalled connection: --auto-update runs before every skill.
  if ! curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 300 "$url" -o "$TMP/src.tgz"; then
    die "failed to download $url (unknown tag, rate-limited or offline)"
  fi
  # GitHub tarballs carry the commit in a pax global header ("52 comment=<sha>").
  SOURCE_ID=$(gzip -dc "$TMP/src.tgz" | head -c 2048 | tr -d '\0' | grep -a -o 'comment=[0-9a-f]*' | head -1 | cut -d= -f2 || true)
  [[ -n "$SOURCE_ID" ]] || SOURCE_ID="remote-$label"
  VERSION_ID=$label
  mkdir "$TMP/x"
  tar -xzf "$TMP/src.tgz" -C "$TMP/x"
  # GitHub names the top directory mx-harness-main, or mx-harness-1.2.0 for tag v1.2.0.
  for d in "$TMP/x"/*/; do SRC=${d%/}; break; done
  [[ -n "$SRC" && -f "$SRC/${SKILLS[0]}/SKILL.md" ]] || die "unexpected archive layout in $url"
}

resolve_source() {
  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
  LOCAL_SOURCE_ROOT="$script_dir"
  if $REMOTE || [[ -n "$REF" || ! -f "$script_dir/${SKILLS[0]}/SKILL.md" ]]; then
    fetch_remote
    return
  fi
  SRC="$script_dir"
  if [[ -d "$SRC/.git" ]]; then
    # An explicit length: under core.abbrev=no a full sha would make auto_update
    # treat this clone as a release install.
    SOURCE_ID=$(git -C "$SRC" rev-parse --short=7 HEAD 2>/dev/null || true)
    if [[ -n "$SOURCE_ID" && -n "$(git -C "$SRC" status --porcelain 2>/dev/null)" ]]; then
      SOURCE_ID="$SOURCE_ID+dirty"
    fi
  fi
  [[ -n "$SOURCE_ID" ]] || SOURCE_ID="local:$SRC"
  # -e, not -d: in a worktree or submodule .git is a file.
  if [[ -e "$SRC/.git" ]]; then
    VERSION_ID=$(git -C "$SRC" describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --dirty 2>/dev/null || true)
  fi
  [[ -n "$VERSION_ID" ]] || VERSION_ID="unknown"
}

# --- per-skill ---

check_install_path() {
  local path=$1 canon=$2 src=$3 parent physical home_real canon_base
  if [[ -d "$path" && ! -L "$path" &&
        ( "$(realdir "$path")" == "$(realdir "$src")" ||
          "$(realdir "$path")" == "$(realdir "$LOCAL_SOURCE_ROOT/${src##*/}")" ) ]]; then
    echo "  error: refusing to replace source directory $path" >&2
    return 1
  fi
  if [[ -e "$path" && ! -d "$path" && ! -L "$path" ]]; then
    echo "  error: $path is not a skill directory" >&2
    return 1
  fi
  home_real=$(realdir "$HOME")
  canon_base=$(realdir "$CANON_BASE")
  parent=$(dirname "$path")
  while [[ "$parent" != / ]]; do
    if [[ -L "$parent" ]]; then
      physical=$(realdir "$parent")
      # Allow the system's home-path aliases and an agent alias to canonical.
      if [[ -z "$physical" || ( "$home_real/" != "$physical/"* &&
            ( "$path" == "$canon" || "$physical" != "$canon_base" ) ) ]]; then
        echo "  error: parent symlink $parent would modify its target; use individual skill links instead" >&2
        return 1
      fi
    fi
    parent=$(dirname "$parent")
  done
}

# A previous installation can supply files without owning its checkout target.
find_seed() {
  local skill=$1 d home
  d=$(lock_get "$skill" root)
  if [[ -n "$d" && -d "$d" ]]; then echo "$d"; return; fi
  for home in "${AGENT_HOMES[@]}"; do
    d="$home/skills/$skill"
    if [[ -d "$d" ]]; then echo "$d"; return; fi
  done
}

# Compare all active references before changing any installation.
collect_reference_edits() {
  local skill=$1 src=$2 merged=$3 d f rel cur locked upstream
  shift 3
  for d in "$@"; do
    [[ -d "$d/references" ]] || continue
    if ! find -L "$d/references" -type f -print0 > "$merged/reference-files"; then
      echo "  error: cannot inspect references at $d; installations left unchanged" >&2
      return 1
    fi
    while IFS= read -r -d '' f; do
      rel="${f#$d/}"
      cur=$(sha256 "$f") || return 1
      locked=$(lock_get "$skill" "$rel")
      upstream=""
      [[ ! -f "$src/$rel" ]] || upstream=$(sha256 "$src/$rel") || return 1
      [[ "$cur" != "$locked" && "$cur" != "$upstream" ]] || continue
      if [[ -f "$merged/$rel" ]] && [[ "$cur" != "$(sha256 "$merged/$rel")" ]]; then
        echo "  error: conflicting local edits to $skill/$rel at $d; installations left unchanged" >&2
        return 1
      fi
      mkdir -p "$(dirname "$merged/$rel")" || return 1
      cp "$f" "$merged/$rel" || return 1
    done < "$merged/reference-files"
  done
}

# Copy src -> dst honouring the hash lock. Prints one line per changed file.
sync_skill_files() {
  local skill=$1 src=$2 dst_dir=$3 manifest=$4
  local f rel dst src_hash cur locked s
  local changed=0 same=0
  local skipped=()
  while IFS= read -r -d '' f; do
    rel="${f#$src/}"
    dst="$dst_dir/$rel"
    src_hash=$(sha256 "$f") || return 1
    if [[ -f "$dst" ]]; then
      cur=$(sha256 "$dst") || return 1
      if [[ "$cur" == "$src_hash" ]]; then
        lock_set "$skill" "$rel" "$cur"
        same=$((same + 1))
        continue
      fi
      if [[ "$rel" == references/* ]]; then
        locked=$(lock_get "$skill" "$rel")
        if [[ -z "$locked" || "$cur" != "$locked" ]]; then
          skipped+=("$rel")
          continue
        fi
      fi
    fi
    mkdir -p "$(dirname "$dst")" || return 1
    cp "$f" "$dst" || return 1
    lock_set "$skill" "$rel" "$src_hash"
    changed=$((changed + 1))
    echo "  ✓ $rel"
  done < "$manifest"
  for s in ${skipped[@]+"${skipped[@]}"}; do
    echo "  ~ $s (skipped — local changes preserved)"
  done
  echo "  $changed updated, $same unchanged, ${#skipped[@]} preserved"
}

# Replace the installation entry, never write through its old symlink target.
ensure_link() {
  local skill=$1 link=$2 canon=$3
  if [[ -d "$link" && "$(realdir "$link")" == "$(realdir "$canon")" ]]; then
    return 0
  fi
  if [[ -L "$link" ]]; then
    move_to_backup "$link" || return 1
  elif [[ -d "$link" ]]; then
    move_to_backup "$link" || return 1
  elif [[ -e "$link" ]]; then
    echo "  ! $link is not a directory; left alone"
    return 0
  fi
  mkdir -p "$(dirname "$link")" || return 1
  ln -s "$canon" "$link" || return 1
  echo "  ↪ $link -> $canon"
}

install_skill() (
  local skill=$1 src="$SRC/$skill" canon="$CANON_BASE/$skill" seed home root merged
  local dirs=()
  [[ -f "$src/SKILL.md" ]] || { echo "  error: $skill/SKILL.md not found in $SRC" >&2; return 1; }

  root=$(lock_get "$skill" root)
  check_install_path "$canon" "$canon" "$src" || return 1
  [[ -z "$root" ]] || check_install_path "$root" "$canon" "$src" || return 1
  [[ ! -d "$root" ]] || dirs+=("$root")
  [[ ! -d "$canon" ]] || dirs+=("$canon")
  for home in "${AGENT_HOMES[@]}"; do
    [[ ! -d "$home" ]] || check_install_path "$home/skills/$skill" "$canon" "$src" || return 1
    [[ ! -d "$home/skills/$skill" ]] || dirs+=("$home/skills/$skill")
  done
  merged=$(mktemp -d) || return 1
  trap 'rm -rf "$merged"' EXIT
  find "$src" -type f ! -name '.*' -print0 > "$merged/source-files" || return 1
  collect_reference_edits "$skill" "$src" "$merged" ${dirs[@]+"${dirs[@]}"} || return 1

  if [[ -L "$canon" && ! -e "$canon" ]]; then
    move_to_backup "$canon" || return 1
  fi
  if [[ -L "$canon" || ( -d "$canon" && -n "$(find "$canon" -type l -print -quit)" ) ]]; then
    cp -RL "$canon/." "$merged/canonical" || return 1
    move_to_backup "$canon" || return 1
    mv "$merged/canonical" "$canon" || return 1
  fi
  if [[ ! -d "$canon" ]]; then
    seed=$(find_seed "$skill")
    mkdir -p "$CANON_BASE" || return 1
    if [[ -n "$seed" ]]; then
      cp -RL "$seed" "$canon" || return 1
      echo "  seeded from $seed"
    fi
  fi
  mkdir -p "$canon" || return 1
  if [[ -d "$merged/references" ]]; then
    cp -R "$merged/references" "$canon/" || return 1
  fi
  sync_skill_files "$skill" "$src" "$canon" "$merged/source-files" || return 1

  for home in "${AGENT_HOMES[@]}"; do
    [[ -d "$home" ]] || continue
    ensure_link "$skill" "$home/skills/$skill" "$canon" || return 1
  done
  if [[ -n "$root" && ( -e "$root" || -L "$root" ) ]]; then
    ensure_link "$skill" "$root" "$canon" || return 1
  fi
  lock_set "$skill" root "$canon"
)

# --- retired skills ---

prune_skill() {
  local skill=$1 home link root d
  root=$(lock_get "$skill" root)
  check_install_path "$CANON_BASE/$skill" "$CANON_BASE/$skill" "$SRC/$skill" || return 1
  [[ -z "$root" ]] || check_install_path "$root" "$CANON_BASE/$skill" "$SRC/$skill" || return 1
  for home in "${AGENT_HOMES[@]}"; do
    [[ ! -d "$home" ]] || check_install_path "$home/skills/$skill" "$CANON_BASE/$skill" "$SRC/$skill" || return 1
  done
  for home in "${AGENT_HOMES[@]}"; do
    link="$home/skills/$skill"
    if [[ -L "$link" ]]; then
      if [[ ! -e "$link" || "$(realdir "$link")" == "$(realdir "$CANON_BASE/$skill")" || "$(realdir "$link")" == "$(realdir "$root")" ]]; then
        rm -f "$link" || return 1
        echo "  removed link $link"
      else
        echo "  ~ $link -> $(readlink "$link") (foreign symlink, left alone)"
      fi
    elif [[ -d "$link" ]]; then
      move_to_backup "$link" || return 1
    fi
  done
  for d in "$CANON_BASE/$skill" "$root"; do
    if [[ -n "$d" && ( -d "$d" || -L "$d" ) ]]; then
      move_to_backup "$d" || return 1
    fi
  done
  lock_del_skill "$skill"
}

report_orphans() {
  local s failed_prune=0
  local orphans=()
  while IFS= read -r s; do
    [[ -n "$s" ]] || continue
    in_list "$s" "${SKILLS[@]}" || orphans+=("$s")
  done < <(lock_skills)
  [[ ${#orphans[@]} -gt 0 ]] || return 0
  echo "==> no longer shipped: ${orphans[*]}"
  for s in "${orphans[@]}"; do
    if $PRUNE; then
      if ! prune_skill "$s"; then
        echo "  error: could not remove $s" >&2
        failed_prune=1
      fi
    else
      echo "  $s: re-run with --prune to remove it"
    fi
  done
  echo
  return "$failed_prune"
}

# Every skill runs this copy with --auto-update. It is the installer of the
# release just installed, so the next update starts from the newest code.
install_self() {
  local dest="$HOME/.mx/.mx-harness-install.sh"
  # Replace by rename, never in place: a running --auto-update may have started
  # this installer, and bash would go on reading the rewritten file.
  cp "$SRC/install.sh" "$dest.tmp.$$"
  mv -f "$dest.tmp.$$" "$dest"
}

# --- auto-update (contract: README.md "Automatic updates") ---
AUTO_RUNNING="$HOME/.mx/.mx-harness-update.running"  # mutex dir: parallel sessions update once
# A live update can take 20 minutes on a stalling network (fetch_remote: 4 tries
# of up to 300 s); an older mutex was left by a killed run.
AUTO_STALE_MINUTES=30

semver_sort() { sort -u -t. -k1,1n -k2,2n -k3,3n; }

# Runs in a subshell without errexit: it must never fail the skill that called it.
# Prints nothing unless an update was installed or failed.
auto_update() {
  local version source major best out
  # On unless turned off with 0, false or off, in any case.
  case "$(printf '%s' "${MX_HARNESS_AUTO_UPDATE:-}" | tr '[:upper:]' '[:lower:]')" in
    0|false|off) return 0 ;;
  esac
  version=$(lock_get _meta version)
  source=$(lock_get _meta source)
  # Release installs only. A clone sitting on a tag records a short sha instead.
  [[ "$version" =~ ^v([0-9]+)\.[0-9]+\.[0-9]+$ ]] || return 0
  major=${BASH_REMATCH[1]}
  [[ "$source" =~ ^([0-9a-f]{40}|remote-v[0-9.]+)$ ]] || return 0
  command -v curl >/dev/null 2>&1 || return 0

  # Newest tag of the same major: a major release needs manual steps (README
  # "Versions"). The list is the one `git ls-remote` reads, fetched with curl for
  # a hard timeout; not the REST API, which rate-limits per IP like
  # raw.githubusercontent.com (see the header).
  best=$(curl -fsSL --connect-timeout 3 --max-time 8 "$REPO.git/info/refs?service=git-upload-pack" 2>/dev/null \
    | tr -d '\0' \
    | grep -a -o -E 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+(\^\{\})?$' \
    | sed -e 's|^refs/tags/v||' -e 's|\^{}$||' \
    | awk -F. -v m="$major" '$1 == m' | semver_sort | tail -n 1) || return 0
  [[ -n "$best" && "v$best" != "$version" ]] || return 0
  # Never downgrade, e.g. when the installed tag was deleted upstream.
  [[ "$(printf '%s\n%s\n' "${version#v}" "$best" | semver_sort | tail -n 1)" == "$best" ]] || return 0

  REF="v$best"
  fetch_remote >/dev/null 2>&1  # sets SRC; on failure it exits this subshell
  if ! mkdir "$AUTO_RUNNING" 2>/dev/null; then
    [[ -n "$(find "$AUTO_RUNNING" -maxdepth 0 -mmin +"$AUTO_STALE_MINUTES" 2>/dev/null)" ]] || return 0
    rm -rf "$AUTO_RUNNING" && mkdir "$AUTO_RUNNING" 2>/dev/null || return 0
  fi
  trap 'rm -rf "$TMP" "$AUTO_RUNNING"' EXIT
  # The session that held the mutex before us may have installed it already.
  [[ "$(lock_get _meta version)" == "$version" ]] || return 0
  # The new release's own installer, so it installs with its own rules.
  if out=$(bash "$SRC/install.sh" --ref "$REF" 2>&1); then
    echo "mx-harness updated $version -> $REF."
    # Nobody watched this install: name each path it moved out of the way.
    printf '%s\n' "$out" | grep -F '↳ moved ' || true
  else
    echo "mx-harness auto-update to $REF failed; last installer output:"
    printf '%s\n' "$out" | tail -n 5
  fi
}

# --- main ---

REMOTE=false
PRUNE=false
AUTO_UPDATE=false
REF=""
REF_SET=false
SELECTED=()
while [[ $# -gt 0 ]]; do
  arg=$1; shift
  case "$arg" in
    --auto-update) AUTO_UPDATE=true ;;
    --remote) REMOTE=true ;;
    --prune) PRUNE=true ;;
    --ref)
      [[ $# -gt 0 ]] || die "--ref needs a release tag (vX.Y.Z)"
      REF=$1; REF_SET=true; shift ;;
    --ref=*) REF=${arg#--ref=}; REF_SET=true ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $arg (see --help)" ;;
    *)
      in_list "$arg" "${SKILLS[@]}" || die "unknown skill: $arg (available: ${SKILLS[*]})"
      SELECTED+=("$arg")
      ;;
  esac
done
if $AUTO_UPDATE; then
  ( set +e; auto_update ) || true
  exit 0
fi
# Strict pattern: the tag is interpolated into the download URL.
if $REF_SET && ! [[ "$REF" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  die "--ref must be a release tag like v1.2.0 (vX.Y.Z), got: '$REF'"
fi
[[ ${#SELECTED[@]} -gt 0 ]] || SELECTED=("${SKILLS[@]}")

mkdir -p "$HOME/.mx"
resolve_source
echo "Source:    $SRC ($SOURCE_ID)"
echo "Version:   $VERSION_ID"
echo "Canonical: $CANON_BASE"
echo

failed=()
for skill in "${SELECTED[@]}"; do
  echo "==> $skill"
  install_skill "$skill" || failed+=("$skill")
  echo
done
report_orphans || failed+=("prune")

linked=""
for home in "${AGENT_HOMES[@]}"; do
  [[ -d "$home" ]] && linked="$linked $(basename "$home")/skills"
done
[[ -n "$linked" ]] || linked=" none found (no ~/.claude, ~/.codex, ~/.cursor or ~/.copilot) — canonical copy only"

if [[ ${#failed[@]} -eq 0 ]]; then
  lock_set _meta source "$SOURCE_ID"
  lock_set _meta version "$VERSION_ID"
  install_self
  echo "Done. ${#SELECTED[@]} skill(s) at $CANON_BASE ($VERSION_ID); linked from:$linked"
else
  echo "Done with ${#failed[@]} failure(s): ${failed[*]}"
  exit 1
fi

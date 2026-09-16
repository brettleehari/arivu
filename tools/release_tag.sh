#!/usr/bin/env bash
# Platform-prefixed release tags and per-platform changelogs (MULTIPLATFORM.md "Versioning and
# releases"): core/v1.4.0, android/v1.2.0, ios/v1.1.3.
#
# One history, independent cadences. Android 1.2.0 and iOS 1.1.3 can both run core 1.4.0, and an
# Android fix is never held for App Store review. The prefix is what makes
# `git log core/v1.3.0..core/v1.4.0` useful.
#
#   tools/release_tag.sh list                       every arivu tag, newest first
#   tools/release_tag.sh changelog android          since the last android/v* tag
#   tools/release_tag.sh changelog core --since core/v1.3.0 --to HEAD
#   tools/release_tag.sh tag android 1.2.0          write the annotated tag (never pushes)
#   tools/release_tag.sh tag android 1.2.0 --push   ...and push it
#
# Changelogs come from conventional-commit scopes — feat(core):, fix(android):, chore(tools): —
# because that is the only per-platform signal a single history carries. A platform's changelog
# includes the core and tools commits it ships with, under their own heading: a user of the
# Android app is affected by a core fix whether or not it says "android".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "error: $*" >&2; exit 1; }

# bash 3.2 on macOS: no associative arrays.
scopes_for() {
  case "$1" in
    core)    echo "core tools" ;;
    android) echo "android core tools" ;;
    ios)     echo "ios core tools" ;;
    *)       die "unknown platform '$1' (core, android, ios)" ;;
  esac
}

heading_for() {
  case "$1" in
    core)    echo "Core" ;;
    android) echo "Android" ;;
    ios)     echo "iOS" ;;
    tools)   echo "Tools and build" ;;
  esac
}

last_tag() {
  git tag --list "$1/v*" --sort=-v:refname | head -1
}

# ---------------------------------------------------------------------------------------------

cmd_list() {
  local any=0
  for p in core android ios; do
    local tags
    tags="$(git tag --list "$p/v*" --sort=-v:refname)"
    if [[ -n "$tags" ]]; then
      any=1
      echo "$p:"
      while IFS= read -r t; do
        printf '  %-18s %s\n' "$t" "$(git log -1 --format='%ad %s' --date=short "$t" 2>/dev/null)"
      done <<<"$tags"
    fi
  done
  [[ $any == 1 ]] || echo "no arivu release tags yet"
}

# changelog <platform> [--since REF] [--to REF]
cmd_changelog() {
  local platform="${1:-}"
  [[ -n "$platform" ]] || die "usage: $0 changelog <core|android|ios> [--since REF] [--to REF]"
  shift
  local since="" to="HEAD"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since) since="${2:-}"; shift 2 ;;
      --to)    to="${2:-}"; shift 2 ;;
      *)       die "unexpected argument '$1'" ;;
    esac
  done
  local wanted
  wanted="$(scopes_for "$platform")"
  [[ -n "$since" ]] || since="$(last_tag "$platform")"

  local range
  if [[ -n "$since" ]]; then
    git rev-parse -q --verify "$since" >/dev/null || die "no such ref: $since"
    range="$since..$to"
  else
    range="$to"
  fi

  echo "## $platform — $(git rev-parse --short "$to")"
  echo
  if [[ -n "$since" ]]; then
    echo "_Since $since ($(git log -1 --format=%ad --date=short "$since"))._"
  else
    echo "_First release: the whole history._"
  fi
  echo

  local body
  body="$(git log --no-merges --reverse --pretty=format:'%h%x09%s' "$range" || true)"
  [[ -n "$body" ]] || { echo "_No commits._"; return 0; }

  local printed=0
  for scope in $wanted; do
    local lines=""
    while IFS=$'\t' read -r sha subject; do
      [[ -n "$sha" ]] || continue
      # feat(core)!: subject  /  fix(android): subject
      case "$subject" in
        *"($scope)"*:*)
          local kind text breaking=""
          kind="${subject%%(*}"
          text="${subject#*: }"
          case "${subject%%:*}" in *"!") breaking=" **breaking**" ;; esac
          case "$kind" in
            feat|fix|perf|revert|refactor) ;;
            *) [[ "$breaking" != "" ]] || continue ;;   # chore/docs/test/ci are noise in a changelog
          esac
          lines="$lines- $text ($kind$breaking, \`$sha\`)"$'\n'
          ;;
      esac
    done <<<"$body"
    if [[ -n "$lines" ]]; then
      printed=1
      echo "### $(heading_for "$scope")"
      echo
      printf '%s\n' "$lines"
    fi
  done

  # An unscoped or unconventional commit is invisible to a per-platform changelog. Say so rather
  # than dropping it silently.
  local stray=0
  while IFS=$'\t' read -r sha subject; do
    [[ -n "$sha" ]] || continue
    case "$subject" in
      *"("*")"*:*|*:*) ;;
      *) stray=$((stray + 1)) ;;
    esac
  done <<<"$body"
  if [[ $stray -gt 0 ]]; then
    echo "_$stray commit(s) in this range carry no conventional-commit prefix and appear in no"
    echo "per-platform changelog. See MULTIPLATFORM.md \"Conventional commit scopes\"._"
  fi
  [[ $printed == 1 ]] || echo "_Nothing user-visible for $platform in this range._"
}

# tag <platform> <X.Y.Z> [--push]
cmd_tag() {
  local platform="${1:-}" version="${2:-}"
  [[ -n "$platform" && -n "$version" ]] || die "usage: $0 tag <core|android|ios> <X.Y.Z> [--push]"
  scopes_for "$platform" >/dev/null
  shift 2
  local push=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --push) push=1; shift ;;
      *) die "unexpected argument '$1'" ;;
    esac
  done
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must be X.Y.Z, got '$version'"

  local tag="$platform/v$version"
  ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null || die "$tag already exists"
  [[ -z "$(git status --porcelain)" ]] || die "working tree is dirty; commit or stash first"

  # An app version must match the version the artifact will actually declare.
  if [[ "$platform" == android ]]; then
    local declared
    declared="$(grep -E '^arivu.versionName=' android/gradle.properties | cut -d= -f2- | tr -d '[:space:]')"
    [[ "$declared" == "$version" ]] || \
      die "android/gradle.properties says arivu.versionName=$declared, not $version"
  fi

  local notes
  notes="$(cmd_changelog "$platform")"
  git tag -a "$tag" -m "$notes"
  echo "created $tag"
  echo
  printf '%s\n' "$notes"
  echo
  if [[ $push == 1 ]]; then
    git push origin "$tag"
    echo "pushed $tag"
  else
    echo "not pushed. When you are ready:  git push origin $tag"
  fi
}

case "${1:-}" in
  list)      shift; cmd_list "$@" ;;
  changelog) shift; cmd_changelog "$@" ;;
  tag)       shift; cmd_tag "$@" ;;
  *)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac

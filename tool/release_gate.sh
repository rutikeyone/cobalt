#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."

sha=${GITHUB_SHA:?GITHUB_SHA names the tagged commit}
minutes=${RELEASE_GATE_MINUTES:-30}

on_a_release_branch() {
  for branch in main 1.x; do
    git rev-parse --verify --quiet "origin/$branch" > /dev/null || continue
    git merge-base --is-ancestor "$sha" "origin/$branch" && return 0
  done
  return 1
}

ci_verdict() {
  runs=$(gh run list --workflow ci.yml --commit "$sha" --event push \
    --json status,conclusion --jq '.[] | "\(.status) \(.conclusion)"') || exit
  if printf '%s\n' "$runs" | grep -q '^completed success$'; then
    echo green
  elif [ -z "$runs" ]; then
    echo missing
  elif printf '%s\n' "$runs" | grep -qv '^completed '; then
    echo pending
  else
    echo red
  fi
}

if ! on_a_release_branch; then
  echo "::error::$sha is on neither origin/main nor origin/1.x"
  exit 1
fi
echo "$sha is on a release branch"

deadline=$(( $(date +%s) + minutes * 60 ))
while :; do
  verdict=$(ci_verdict) || {
    echo "::error::gh could not list ci runs for $sha"
    exit 1
  }
  case "$verdict" in
    green)
      echo "ci is green on $sha"
      exit 0
      ;;
    red)
      echo "::error::ci failed on $sha"
      exit 1
      ;;
    missing) echo "ci has no push run for $sha" ;;
    pending) echo "ci on $sha has not finished" ;;
  esac
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "::error::ci on $sha did not finish green within $minutes minutes"
    exit 1
  fi
  echo "checking again in 30s"
  sleep 30
done

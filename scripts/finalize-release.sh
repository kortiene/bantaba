#!/usr/bin/env bash

set -euo pipefail

artifact_dir="${1:-dist}"
tag="$RELEASE_TAG"
created_tag=0
release_id=""
published=0
run_marker="jeliya-release-run:${GITHUB_RUN_ID}:${GITHUB_RUN_ATTEMPT}"
notes_file="$RUNNER_TEMP/jeliya-release-notes.md"
lookup_delay="${JELIYA_RELEASE_LOOKUP_DELAY_SECONDS:-2}"
case "$lookup_delay" in
  '' | *[!0-9]*) echo "invalid release lookup delay" >&2; exit 2 ;;
esac
printf '%s\n\n<!-- %s -->\n' "$RELEASE_BODY" "$run_marker" > "$notes_file"

lookup_release_id() {
  local filter="$1"
  local attempt=1
  local candidate
  while [ "$attempt" -le 3 ]; do
    candidate="$(gh api "repos/${GITHUB_REPOSITORY}/releases?per_page=100" \
      --jq "$filter" 2>/dev/null || true)"
    if [ -n "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    if [ "$attempt" -lt 3 ] && [ "$lookup_delay" -gt 0 ]; then
      sleep "$lookup_delay"
    fi
    attempt=$((attempt + 1))
  done
  return 1
}

cleanup_failed_publication() {
  status=$?
  trap - EXIT INT TERM
  if [ "$published" -ne 1 ]; then
    candidate_id="$release_id"
    release_lookup_ok=1
    safe_to_delete_tag=1
    if [ -z "$candidate_id" ]; then
      if ! candidate_id="$(lookup_release_id \
        ".[] | select(.tag_name == \"${tag}\") | .id")"; then
        release_lookup_ok=0
        safe_to_delete_tag=0
        echo "warning: could not reconcile a release created for $tag; preserving its tag" >&2
      fi
    fi
    if [ -n "$candidate_id" ]; then
      draft_state="$(gh api "repos/${GITHUB_REPOSITORY}/releases/${candidate_id}" \
        --jq '.draft' 2>/dev/null || true)"
      candidate_body="$(gh api "repos/${GITHUB_REPOSITORY}/releases/${candidate_id}" \
        --jq '.body // ""' 2>/dev/null || true)"
      if [ "$draft_state" = "false" ]; then
        safe_to_delete_tag=0
        current_sha="$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/tags/${tag}" \
          --jq '.object.sha' 2>/dev/null || true)"
        if [ "$created_tag" -eq 1 ] && [ "$current_sha" = "$GITHUB_SHA" ] && \
           printf '%s' "$candidate_body" | grep -Fq "<!-- $run_marker -->"; then
          # The final PATCH succeeded but its response was lost. A public,
          # run-owned release at the exact tag SHA is the successful terminal
          # state, so reconcile the workflow result instead of reporting red.
          published=1
          status=0
          echo "release $tag is public and run-owned; reconciled lost PATCH response" >&2
        else
          echo "warning: public release $candidate_id could not be proven run-owned; preserving it" >&2
        fi
      elif [ "$draft_state" = "true" ]; then
        if [ "$created_tag" -ne 1 ] || \
           ! printf '%s' "$candidate_body" | grep -Fq "<!-- $run_marker -->"; then
          safe_to_delete_tag=0
          echo "warning: draft $candidate_id is not owned by this run; preserving it" >&2
        elif ! gh api "repos/${GITHUB_REPOSITORY}/releases/${candidate_id}" \
          --method DELETE >/dev/null 2>&1; then
          safe_to_delete_tag=0
          echo "warning: could not remove failed draft release $candidate_id" >&2
        fi
      else
        safe_to_delete_tag=0
        echo "warning: could not confirm release state for $candidate_id" >&2
      fi
    fi
    if [ "$published" -ne 1 ] && [ "$release_lookup_ok" -eq 1 ] && \
       [ "$safe_to_delete_tag" -eq 1 ] && [ "$created_tag" -eq 1 ]; then
      current_sha="$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/tags/${tag}" \
        --jq '.object.sha' 2>/dev/null || true)"
      if [ "$current_sha" = "$GITHUB_SHA" ]; then
        gh api "repos/${GITHUB_REPOSITORY}/git/refs/tags/${tag}" \
          --method DELETE >/dev/null 2>&1 || \
          echo "warning: could not remove failed run-owned tag $tag" >&2
      fi
    fi
  fi
  exit "$status"
}

existing="$(gh api "repos/${GITHUB_REPOSITORY}/releases?per_page=100" \
  --jq ".[] | select(.tag_name == \"${tag}\") | .id")"
test -z "$existing" || {
  echo "release $tag already exists (id $existing); refusing to mutate it" >&2
  exit 1
}
if git ls-remote --exit-code --tags \
  "https://github.com/${GITHUB_REPOSITORY}.git" \
  "refs/tags/$tag" >/dev/null 2>&1; then
  echo "tag $tag already exists; refusing to mutate it" >&2
  exit 1
fi

assets=("$artifact_dir"/*)
test "${#assets[@]}" -eq 10
# No cleanup trap is active during the refusal checks above: this run does not
# own an existing draft or tag and must never delete either.
trap cleanup_failed_publication EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
gh api "repos/${GITHUB_REPOSITORY}/git/refs" \
  --method POST \
  -f ref="refs/tags/${tag}" \
  -f sha="$GITHUB_SHA" \
  >/dev/null
created_tag=1
# `gh release create` is the only gh call here that does not take an explicit
# `repos/<owner>/<repo>` path, so it must be told the repository: the publish
# job has no working-tree checkout, and without --repo gh tries to resolve the
# repository from local git and fails with "not a git repository".
gh release create "$tag" "${assets[@]}" \
  --repo "${GITHUB_REPOSITORY}" \
  --verify-tag \
  --target "$GITHUB_SHA" \
  --title "Jeliya $tag — Evidence-Backed Technical Preview" \
  --notes-file "$notes_file" \
  --generate-notes \
  --draft \
  --prerelease \
  --latest=false

release_id="$(lookup_release_id \
  ".[] | select(.tag_name == \"${tag}\" and .draft == true) | .id" || true)"
test -n "$release_id" || {
  echo "draft release $tag was not found after upload" >&2
  exit 1
}

remote_count="$(gh api "repos/${GITHUB_REPOSITORY}/releases/${release_id}/assets?per_page=100" --jq 'length')"
test "$remote_count" -eq 10 || {
  echo "draft has $remote_count assets; expected 10" >&2
  exit 1
}
for file in "${assets[@]}"; do
  name="$(basename "$file")"
  local_size="$(stat -c '%s' "$file")"
  remote_size="$(gh api "repos/${GITHUB_REPOSITORY}/releases/${release_id}/assets?per_page=100" \
    --jq ".[] | select(.name == \"${name}\") | .size")"
  test "$remote_size" = "$local_size" || {
    echo "remote asset mismatch for $name: size '$remote_size', expected '$local_size'" >&2
    exit 1
  }
  asset_id="$(gh api "repos/${GITHUB_REPOSITORY}/releases/${release_id}/assets?per_page=100" \
    --jq ".[] | select(.name == \"${name}\") | .id")"
  test -n "$asset_id" || {
    echo "remote asset id missing for $name" >&2
    exit 1
  }
  remote_copy="$RUNNER_TEMP/remote-${asset_id}"
  gh api \
    -H 'Accept: application/octet-stream' \
    "repos/${GITHUB_REPOSITORY}/releases/assets/${asset_id}" \
    > "$remote_copy"
  cmp -s "$file" "$remote_copy" || {
    echo "remote bytes differ for $name" >&2
    exit 1
  }
done

tag_sha="$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/tags/${tag}" --jq '.object.sha')"
test "$tag_sha" = "$GITHUB_SHA" || {
  echo "tag $tag moved during publication" >&2
  exit 1
}

final_default_tip="$(git ls-remote --exit-code --heads \
  "https://github.com/${GITHUB_REPOSITORY}.git" \
  "refs/heads/$DEFAULT_BRANCH" | awk 'NF == 2 { print $1 }')"
test "$final_default_tip" = "$GITHUB_SHA" || {
  echo "default branch moved during publication; cleaning this run's draft and tag" >&2
  exit 1
}

gh api "repos/${GITHUB_REPOSITORY}/releases/${release_id}" \
  --method PATCH \
  -F draft=false \
  -F prerelease=true \
  >/dev/null
published=1

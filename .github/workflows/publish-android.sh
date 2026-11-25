#!/usr/bin/env bash
set -euo pipefail

cd apk-artifact
[[ "$(cat source-commit.txt)" == "${GITHUB_SHA:?}" ]]
version="$(jq -er '.version' android-update.json)"
code="$(jq -er '.versionCode' android-update.json)"
asset="$(jq -er '.apk' android-update.json)"
tag="v$version"
sha256sum --check "$asset.sha256"

if existing="$(gh release view "$tag" --json isDraft,isPrerelease,targetCommitish)"; then
  existing_draft="$(jq -r '.isDraft' <<< "$existing")"
  if [[ "$existing_draft" == true ]]; then
    [[ "$(jq -r '.targetCommitish' <<< "$existing")" == "$GITHUB_SHA" ]] || {
      echo "::error::Draft $tag targets another commit"
      exit 1
    }
  else
    [[ "$(jq -r '.isPrerelease' <<< "$existing")" == false ]]
  fi
else
  existing_draft=""
fi

tag_sha="$(git ls-remote origin "refs/tags/$tag" "refs/tags/$tag^{}" | tail -n 1 | cut -f 1)"
if [[ -n "$tag_sha" && "$tag_sha" != "$GITHUB_SHA" ]]; then
  echo "::error::Tag $tag belongs to $tag_sha"
  exit 1
fi
if [[ "$existing_draft" == false ]]; then
  [[ "$tag_sha" == "$GITHUB_SHA" ]]
  printf 'Stable release %s already exists at %s\n' "$tag" "$tag_sha"
  exit 0
fi

# The latest public release can only be absent when the repository has no stable release.
stable_releases="$(gh api --paginate "repos/${GITHUB_REPOSITORY:?}/releases?per_page=100" --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name')" || {
  echo 'Could not determine the prior stable release.'
  exit 1
}
latest_tag="${stable_releases%%$'\n'*}"
if [[ -n "$latest_tag" ]]; then
  prior="$(mktemp -d)"
  trap 'rm -rf "$prior"' EXIT
  gh release download "$latest_tag" --pattern android-update.json --dir "$prior"
  python3 - "$prior/android-update.json" "$latest_tag" "$version" "$code" <<'PY'
import json
import re
import sys

path, tag, current, code = sys.argv[1:]
with open(path, encoding="utf-8") as source:
    prior = json.load(source)

def semver(value):
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", value):
        raise SystemExit("Invalid stable release version")
    return tuple(map(int, value.split(".")))

if (
    tag != f"v{prior['version']}"
    or prior["applicationId"] != "org.sodukromental"
    or semver(current) <= semver(prior["version"])
    or type(prior["versionCode"]) is not int
    or int(code) <= prior["versionCode"]
):
    raise SystemExit("Stable release must advance version and version code for org.sodukromental")
PY
fi

if [[ -z "$existing_draft" ]]; then
  gh release create "$tag" --draft --target "$GITHUB_SHA" --title "Sodukromental $version" --generate-notes
fi
gh release upload "$tag" "$asset" "$asset.sha256" android-update.json --clobber
gh release edit "$tag" --draft=false --latest

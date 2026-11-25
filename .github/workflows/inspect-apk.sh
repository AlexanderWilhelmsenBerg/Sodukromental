#!/usr/bin/env bash
set -euo pipefail

kind="${1:?Expected APK build type}"
version_record="$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)$/\1/p' pubspec.yaml)"
[[ "$version_record" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\+[1-9][0-9]{0,9}$ ]]
version="${version_record%+*}"
code="${version_record##*+}"
(( code <= 2100000000 ))

sdk_tools="${ANDROID_HOME:?}/build-tools/36.0.0"
apk="build/app/outputs/flutter-apk/app-$kind.apk"
application_id="org.sodukromental"
asset="sodukromental-$version-android.apk"
if [[ "$kind" == debug ]]; then
  application_id+=".debug"
  asset="sodukromental-$version-debug-android.apk"
fi

badging="$("$sdk_tools/aapt" dump badging "$apk")"
[[ "$badging" == "package: name='$application_id' versionCode='$code' versionName='$version'"* ]]
signature="$("$sdk_tools/apksigner" verify --print-certs "$apk")"
if [[ "$kind" == release ]]; then
  expected="$(printf '%s' "${SODU_RELEASE_CERT_SHA256:?}" | tr -d ':' | tr '[:upper:]' '[:lower:]')"
  [[ "$expected" =~ ^[a-f0-9]{64}$ ]]
  actual="$(sed -n 's/^Signer #[0-9]* certificate SHA-256 digest: //p' <<< "$signature")"
  [[ "$actual" == "$expected" ]]
fi

mkdir -p apk-artifact
cp "$apk" "apk-artifact/$asset"
(
  cd apk-artifact
  sha256sum "$asset" > "$asset.sha256"
  printf '%s\n' "${GITHUB_SHA:?}" > source-commit.txt
  printf '%s\n' "${badging%%$'\n'*}" "$signature" > apk-signature.txt
  if [[ "$kind" == release ]]; then
    jq -n --arg applicationId "$application_id" --arg version "$version" --argjson versionCode "$code" --arg apk "$asset" \
      '{applicationId: $applicationId, version: $version, versionCode: $versionCode, apk: $apk}' > android-update.json
  fi
)

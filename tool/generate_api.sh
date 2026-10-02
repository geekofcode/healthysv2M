#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=7.17.0
expected_sha=25d6bd8273dd2be99979d544b62ea43f0ce1975f1aa582678b5093d1e7fcfce8
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/healthys"
jar="$cache_dir/openapi-generator-$version.jar"
mkdir -p "$cache_dir"
if [[ ! -f "$jar" ]]; then
  curl --fail --location --retry 3 "https://repo.maven.apache.org/maven2/org/openapitools/openapi-generator-cli/$version/openapi-generator-cli-$version.jar" --output "$jar"
fi
actual_sha=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$jar")
[[ "$actual_sha" == "$expected_sha" ]] || { echo 'OpenAPI generator checksum mismatch' >&2; exit 1; }
spec="${OPENAPI_SPEC:-openapi/healthys-bootstrap.yaml}"
java -jar "$jar" validate -i "$spec"
# Remove only generated sources, preventing stale endpoints after contract changes.
rm -rf packages/healthys_api/lib
java -jar "$jar" generate -g dart-dio -i "$spec" -c openapi/generator.yaml \
  -o packages/healthys_api \
  --global-property apiTests=false,modelTests=false,apiDocs=false,modelDocs=false
# Generator 7.17 defaults to Dart 3.5, but current serializers require 3.8+.
python3 - <<'PYTHON'
from pathlib import Path
path = Path('packages/healthys_api/pubspec.yaml')
path.write_text(path.read_text().replace(">=3.5.0 <4.0.0", ">=3.12.2 <4.0.0"))
PYTHON
sed -i.bak '/^pubspec.lock$/d' packages/healthys_api/.gitignore
rm -f packages/healthys_api/.gitignore.bak
(
  cd packages/healthys_api
  if [[ "${1:-}" == '--check' ]]; then
    dart pub get --enforce-lockfile
  else
    dart pub get
  fi
  dart run build_runner build --delete-conflicting-outputs
  dart format lib
)
if [[ "${1:-}" == '--check' ]]; then
  git diff --exit-code -- packages/healthys_api
  [[ -z "$(git ls-files --others --exclude-standard packages/healthys_api)" ]] || {
    echo 'Uncommitted generated API files detected' >&2; exit 1;
  }
fi

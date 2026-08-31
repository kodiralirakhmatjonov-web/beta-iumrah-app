#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf .runtime-dist
trap 'rm -rf .runtime-dist' EXIT
tsc -p tsconfig.json --noEmit false --outDir .runtime-dist
# Production imports are extensionless for the Workers bundler. Create exact-path
# aliases only inside this disposable Node test directory.
for file in .runtime-dist/*.js; do
  base="${file%.js}"
  ln -sf "$(basename "$file")" "$base"
done
node --test test/runtime-production.runtime.mjs

#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_zip="$(mktemp -t djtut-linkkit)"
trap 'rm -f "$task_zip"' EXIT
mkdir -p "$task_root/Vendor/LinkKit"
curl --fail --location --proto '=https' --tlsv1.2 \
  https://github.com/Ableton/LinkKit/releases/download/LinkKit-4.1.2/LinkKit.zip \
  --output "$task_zip"
task_hash="$(shasum -a 256 "$task_zip" | cut -d ' ' -f 1)"
if [ "$task_hash" != '874665a33178403cb5051148467db73cab46397e73d2a0790b5725754df11e66' ]; then
  echo 'The SDK download differs from the verified release. Nothing was installed.' >&2
  exit 1
fi
unzip -oq "$task_zip" 'LinkKit.xcframework/*' 'LinkKitResources.bundle/*' 'LICENSE.md' 'Ableton_Link_UI_Guidelines.pdf' -d "$task_root/Vendor/LinkKit"
echo 'Official LinkKit 4.1.2 downloaded from Ableton. See Vendor/LinkKit/LICENSE.md for its license.'

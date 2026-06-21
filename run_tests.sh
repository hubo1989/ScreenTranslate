#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT="TransFrame.xcodeproj"
SCHEME="TransFrame"
DESTINATION="platform=macOS"

if [[ "${1:-}" == "--performance" ]]; then
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:TransFrameTests/PipelineSmokeTests \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGN_IDENTITY=""
else
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGN_IDENTITY=""
fi

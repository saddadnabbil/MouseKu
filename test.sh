#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc -swift-version 5 Sources/Config.swift Sources/ButtonEngine.swift Sources/Glide.swift Tests/main.swift -o build/tests
build/tests

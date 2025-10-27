#!/usr/bin/env bash
# Simple test script for C language

set -e

# Use the simplified jumpscript script
JUMPSCRIPT_PATH="$(dirname "$(realpath "$0")")/jumpscript_simple"

echo "Testing C language with jumpscript_simple..."
echo "Command: $JUMPSCRIPT_PATH C tests/hello.c arg1 42"

# Run the test
"$JUMPSCRIPT_PATH" C tests/hello.c arg1 42

echo "Test completed successfully!"

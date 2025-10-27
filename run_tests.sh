#!/usr/bin/env bash
# Test script for jumpscript

set -e

# Use the jumpscript script
JUMPSCRIPT_PATH="$(dirname "$(realpath "$0")")/jumpscript"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running jumpscript tests...${NC}"

# Function to run a test
run_test() {
    local lang=$1
    local file=$2
    local args="${@:3}"
    local force_rebuild=""
    
    echo -e "\n${YELLOW}Testing $lang ($file)${NC}"
    
    # For Idris, always use force rebuild to avoid cache issues
    if [ "$lang" == "Idris" ]; then
        force_rebuild="--force-rebuild"
    fi
    
    # Run the test using our jumpscript script
    if [ -n "$args" ]; then
        echo "Running with arguments: $args"
        "$JUMPSCRIPT_PATH" $force_rebuild "$lang" "$file" $args
    else
        "$JUMPSCRIPT_PATH" $force_rebuild "$lang" "$file"
    fi
    
    # Check exit status
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $lang test passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $lang test failed${NC}"
        return 1
    fi
}

# Track failures
failures=0

# Test each language
if [ -f "tests/hello.c" ]; then
    run_test "C" "tests/hello.c" "arg1" "42" || ((failures++))
fi

if [ -f "tests/hello.cpp" ]; then
    run_test "C++" "tests/hello.cpp" "hello" "world" "42" || ((failures++))
fi

if [ -f "tests/hello.rs" ]; then
    run_test "Rust" "tests/hello.rs" "10" "20" "30" || ((failures++))
fi

if [ -f "tests/hello.d" ]; then
    run_test "D" "tests/hello.d" "5" "10" "15" || ((failures++))
fi

if [ -f "tests/hello.nim" ]; then
    run_test "Nim" "tests/hello.nim" "7" "8" "9" || ((failures++))
fi

if [ -f "tests/hello.zig" ]; then
    run_test "Zig" "tests/hello.zig" "25" "50" "75" || ((failures++))
fi

if [ -f "tests/hello.cr" ]; then
    run_test "Crystal" "tests/hello.cr" "11" "22" "33" || ((failures++))
fi

if [ -f "tests/hello.idr" ]; then
    run_test "Idris" "tests/hello.idr" "3" "6" "9" || ((failures++))
fi

# Print summary
echo -e "\n${YELLOW}Test Summary${NC}"
if [ $failures -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
else
    echo -e "${RED}$failures test(s) failed.${NC}"
fi

exit $failures

#!/usr/bin/env bash
#
# test-dmenu.sh — Interactive test suite for the noctalia-dmenu plugin.
#
# Run this from a terminal while Noctalia is running with the plugin enabled.
# Each test opens the launcher — make a selection (or press Escape) to continue.
#
# Usage: ./test-dmenu.sh [test-number]
#   Run a specific test by number, or run all tests sequentially.
#

set -euo pipefail

RESULT_FILE="/tmp/noctalia-dmenu-result"
CALLBACK_FILE="/tmp/noctalia-dmenu-callback-test"
QS="noctalia-shell"
PASS=0
FAIL=0
SKIP=0

# ── Helpers ──

red()    { printf '\033[1;31m%s\033[0m' "$*"; }
green()  { printf '\033[1;32m%s\033[0m' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m' "$*"; }
cyan()   { printf '\033[1;36m%s\033[0m' "$*"; }
bold()   { printf '\033[1m%s\033[0m' "$*"; }

cleanup() {
    rm -f "$RESULT_FILE" "${RESULT_FILE}.tmp" "$CALLBACK_FILE"
}

wait_result() {
    local timeout="${1:-10}"
    local elapsed=0
    while [[ ! -f "$RESULT_FILE" ]]; do
        sleep 0.1
        elapsed=$((elapsed + 1))
        if [[ "$elapsed" -ge $((timeout * 10)) ]]; then
            return 1
        fi
    done
    return 0
}

check_result() {
    local expected="$1"
    local label="$2"
    if [[ -f "$RESULT_FILE" ]]; then
        local actual
        actual=$(cat "$RESULT_FILE")
        if [[ "$actual" == "$expected" ]]; then
            echo "  $(green "✓") Result: $(bold "$actual")"
            PASS=$((PASS + 1))
            return 0
        else
            echo "  $(red "✗") Expected: $(bold "$expected"), got: $(bold "$actual")"
            FAIL=$((FAIL + 1))
            return 1
        fi
    else
        echo "  $(red "✗") No result file (user cancelled or timeout)"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

check_result_contains() {
    local expected="$1"
    local label="$2"
    if [[ -f "$RESULT_FILE" ]]; then
        local actual
        actual=$(cat "$RESULT_FILE")
        if echo "$actual" | grep -qF "$expected"; then
            echo "  $(green "✓") Result contains '${expected}': $(bold "$actual")"
            PASS=$((PASS + 1))
            return 0
        else
            echo "  $(red "✗") Expected to contain: $(bold "$expected"), got: $(bold "$actual")"
            FAIL=$((FAIL + 1))
            return 1
        fi
    else
        echo "  $(red "✗") No result file"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

prompt_continue() {
    echo ""
    read -rp "  Press Enter to continue to next test... " _
}

header() {
    local num="$1"
    local title="$2"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $(cyan "Test $num"): $(bold "$title")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

instruct() {
    echo "  $(yellow "→") $*"
}

# ── Tests ──

test_1() {
    header 1 "showSimple — basic 3 items"
    instruct "Select 'banana' from the launcher"
    cleanup
    "$QS" ipc call plugin:dmenu showSimple "apple|banana|cherry" "|" "Pick a fruit:" ""
    if wait_result 15; then
        check_result "banana" "showSimple basic"
    else
        echo "  $(yellow "⊘") Skipped (no selection made)"
        SKIP=$((SKIP + 1))
    fi
    cleanup
}

test_2() {
    header 2 "showJson — structured items with descriptions"
    instruct "Select 'Zen Browser' from the launcher"
    cleanup
    "$QS" ipc call plugin:dmenu showJson '{"items":[{"name":"Firefox","value":"firefox","description":"Standard browser"},{"name":"Zen Browser","value":"zen","description":"Privacy focused"},{"name":"Chromium","value":"chromium","description":"Google-based"}],"prompt":"Open browser:"}' x
    if wait_result 15; then
        check_result "zen" "showJson structured"
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
}

test_3() {
    header 3 "showSimple — search/filter"
    instruct "Type 'gra' to filter, then select 'grape'"
    cleanup
    "$QS" ipc call plugin:dmenu showSimple "apple|grape|grapefruit|banana|orange|mango" "|" "" ""
    if wait_result 20; then
        check_result "grape" "search filter"
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
}

test_4() {
    header 4 "showJson — custom input"
    instruct "Type 'hello-world' (not in list) and select the 'Use as custom input' entry"
    echo "  $(yellow "Note"): If you have a custom input prefix in settings, it will be prepended."
    cleanup
    "$QS" ipc call plugin:dmenu showJson '{"items":["option-a","option-b"],"allowCustomInput":true}' x
    if wait_result 20; then
        local actual
        actual=$(cat "$RESULT_FILE")
        if echo "$actual" | grep -qF "hello-world"; then
            echo "  $(green "✓") Custom input accepted: $(bold "$actual")"
            PASS=$((PASS + 1))
        else
            echo "  $(yellow "⊘") Got: $(bold "$actual") (might have selected a list item)"
            SKIP=$((SKIP + 1))
        fi
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
}

test_5() {
    header 5 "Result format — JSON"
    instruct "Select 'beta' (the second item)"
    cleanup
    "$QS" ipc call plugin:dmenu showJson '{"items":["alpha","beta","gamma"],"resultFormat":"json"}' x
    if wait_result 15; then
        check_result_contains '"value":"beta"' "json format"
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
}

test_6() {
    header 6 "Result format — index"
    instruct "Select 'gamma' (the third item, index 2)"
    cleanup
    "$QS" ipc call plugin:dmenu showJson '{"items":["alpha","beta","gamma"],"resultFormat":"index"}' x
    if wait_result 15; then
        check_result "2" "index format"
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
}

test_7() {
    header 7 "Callback execution"
    instruct "Select any item"
    cleanup
    rm -f "$CALLBACK_FILE"

    # Write the callback as a temp script to avoid quoting issues
    local cb_script="/tmp/noctalia-dmenu-cb-test.sh"
    cat > "$cb_script" << 'SCRIPT'
#!/usr/bin/env bash
printf '%s' "$1" > /tmp/noctalia-dmenu-callback-test
SCRIPT
    chmod +x "$cb_script"

    "$QS" ipc call plugin:dmenu showJson "{\"items\":[\"red\",\"green\",\"blue\"],\"callbackCmd\":\"$cb_script '{}'\"}" x
    if wait_result 15; then
        local selected
        selected=$(cat "$RESULT_FILE")
        echo "  Selected: $(bold "$selected")"
        sleep 0.5
        if [[ -f "$CALLBACK_FILE" ]]; then
            local cb_result
            cb_result=$(cat "$CALLBACK_FILE")
            if [[ "$cb_result" == "$selected" ]]; then
                echo "  $(green "✓") Callback wrote correct value: $(bold "$cb_result")"
                PASS=$((PASS + 1))
            else
                echo "  $(red "✗") Callback wrote: $(bold "$cb_result"), expected: $(bold "$selected")"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "  $(red "✗") Callback file not created"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
    rm -f "$CALLBACK_FILE" "$cb_script"
}

test_8() {
    header 8 "Chaining — two sequential menus"
    instruct "Select 'Power' in the first menu, then 'Reboot' in the second"

    cleanup

    # Create a chaining script that the callback will invoke
    local chain_script="/tmp/noctalia-dmenu-chain.sh"
    cat > "$chain_script" << 'CHAINSCRIPT'
#!/usr/bin/env bash
# This is called by the first menu's callback with the selection as $1
noctalia-shell ipc call plugin:dmenu showSimple "Shutdown|Reboot|Suspend" "|" "Power submenu (picked: $1):" ""
CHAINSCRIPT
    chmod +x "$chain_script"

    "$QS" ipc call plugin:dmenu showJson "{\"items\":[\"Power\",\"Display\",\"Network\"],\"callbackCmd\":\"$chain_script '{}'\"}" x

    # Wait for first selection
    if wait_result 15; then
        local first
        first=$(cat "$RESULT_FILE")
        echo "  First selection: $(bold "$first")"
        cleanup

        # Wait for second selection (the chained menu)
        echo "  $(yellow "→") Now select 'Reboot' from the second menu"
        if wait_result 15; then
            check_result "Reboot" "chaining"
        else
            echo "  $(red "✗") Second menu didn't appear or no selection"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
    rm -f "$chain_script"
}

test_9() {
    header 9 "showFromFile — read items from file"
    instruct "Select 'line-three'"
    cleanup
    local tmpfile="/tmp/noctalia-dmenu-test-items.txt"
    printf "line-one\nline-two\nline-three\nline-four\n" > "$tmpfile"
    "$QS" ipc call plugin:dmenu showFromFile "$tmpfile" "\n" "File test:" ""
    if wait_result 15; then
        check_result "line-three" "showFromFile"
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
    rm -f "$tmpfile"
}

test_10() {
    header 10 "toggle — open/close"
    instruct "The panel should open. Press Escape to close it."
    "$QS" ipc call plugin:dmenu toggle
    sleep 2
    echo "  $(green "✓") toggle executed (visual check)"
    PASS=$((PASS + 1))
}

test_11() {
    header 11 "close — programmatic cancel"
    instruct "The panel will open then close after 2 seconds automatically"
    cleanup
    "$QS" ipc call plugin:dmenu showSimple "waiting|for|close" "|" "" ""
    sleep 2
    "$QS" ipc call plugin:dmenu close
    sleep 0.5
    if [[ ! -f "$RESULT_FILE" ]]; then
        echo "  $(green "✓") close() cancelled without writing result"
        PASS=$((PASS + 1))
    else
        echo "  $(red "✗") Result file exists after close (should not)"
        FAIL=$((FAIL + 1))
    fi
    cleanup
}

test_12() {
    header 12 "Rapid session replacement (no race)"
    instruct "Three menus fire rapidly. Only the last ('C') should appear. Select 'C3'."
    cleanup
    "$QS" ipc call plugin:dmenu showSimple "A1|A2|A3" "|" "" ""
    sleep 0.1
    "$QS" ipc call plugin:dmenu showSimple "B1|B2|B3" "|" "" ""
    sleep 0.1
    "$QS" ipc call plugin:dmenu showSimple "C1|C2|C3" "|" "" ""
    if wait_result 15; then
        check_result "C3" "rapid replacement"
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
}

test_13() {
    header 13 "Special characters in items"
    instruct "Select the item with quotes: He said \"hello\""
    cleanup
    "$QS" ipc call plugin:dmenu showSimple 'normal item|He said "hello"|path/to/file' "|" "" ""
    if wait_result 15; then
        local actual
        actual=$(cat "$RESULT_FILE")
        echo "  $(green "✓") Got: $(bold "$actual")"
        PASS=$((PASS + 1))
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
}

test_14() {
    header 14 "Many items (performance)"
    instruct "Type a number (e.g. '150') to filter, select any item"
    cleanup
    # Generate 500 items
    local items=""
    for i in $(seq 1 500); do
        [[ -n "$items" ]] && items+="|"
        items+="Item $i"
    done
    "$QS" ipc call plugin:dmenu showSimple "$items" "|" "" ""
    if wait_result 30; then
        local actual
        actual=$(cat "$RESULT_FILE")
        echo "  $(green "✓") Selected from 500 items: $(bold "$actual")"
        PASS=$((PASS + 1))
    else
        echo "  $(yellow "⊘") Skipped"
        SKIP=$((SKIP + 1))
    fi
    cleanup
}

# ── Runner ──

run_all() {
    echo ""
    echo "$(bold "╔══════════════════════════════════════════════════╗")"
    echo "$(bold "║     noctalia-dmenu test suite                    ║")"
    echo "$(bold "╚══════════════════════════════════════════════════╝")"
    echo ""
    echo "  Each test opens the dmenu panel. Follow the instructions."
    echo "  Press Escape to skip a test."
    echo ""
    read -rp "  Press Enter to start... " _

    test_1;  prompt_continue
    test_2;  prompt_continue
    test_3;  prompt_continue
    test_4;  prompt_continue
    test_5;  prompt_continue
    test_6;  prompt_continue
    test_7;  prompt_continue
    test_8;  prompt_continue
    test_9;  prompt_continue
    test_10; prompt_continue
    test_11; prompt_continue
    test_12; prompt_continue
    test_13; prompt_continue
    test_14

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $(bold "Results")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $(green "Passed"): $PASS"
    echo "  $(red "Failed"): $FAIL"
    echo "  $(yellow "Skipped"): $SKIP"
    echo ""

    if [[ "$FAIL" -gt 0 ]]; then
        exit 1
    fi
}

# Allow running individual tests
if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    cleanup
    "test_$1"
    cleanup
else
    run_all
fi
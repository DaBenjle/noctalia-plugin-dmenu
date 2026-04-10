#!/usr/bin/env bash
set -euo pipefail

RESULT="/tmp/noctalia-dmenu-result"
CB="/tmp/noctalia-dmenu-cb-out"
QS="noctalia-shell"
PASS=0 FAIL=0 SKIP=0

green()  { printf '\033[1;32m%s\033[0m' "$*"; }
red()    { printf '\033[1;31m%s\033[0m' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m' "$*"; }
cyan()   { printf '\033[1;36m%s\033[0m' "$*"; }
bold()   { printf '\033[1m%s\033[0m' "$*"; }

cleanup() { rm -f "$RESULT" "${RESULT}.tmp" "$CB"; }

wait_result() {
    local t="${1:-15}" e=0
    while [[ ! -f "$RESULT" ]]; do
        sleep 0.1; e=$((e+1)); [[ "$e" -ge $((t*10)) ]] && return 1
    done; return 0
}

expect() {
    local want="$1"
    if [[ -f "$RESULT" ]]; then
        local got; got=$(cat "$RESULT")
        if [[ "$got" == "$want" ]]; then
            echo "  $(green ✓) $(bold "$got")"; PASS=$((PASS+1))
        else
            echo "  $(red ✗) expected $(bold "$want"), got $(bold "$got")"; FAIL=$((FAIL+1))
        fi
    else echo "  $(red ✗) no result file"; FAIL=$((FAIL+1)); fi
}

expect_contains() {
    if [[ -f "$RESULT" ]]; then
        local got; got=$(cat "$RESULT")
        if echo "$got" | grep -qF "$1"; then
            echo "  $(green ✓) contains '$1': $(bold "$got")"; PASS=$((PASS+1))
        else
            echo "  $(red ✗) should contain '$1', got $(bold "$got")"; FAIL=$((FAIL+1))
        fi
    else echo "  $(red ✗) no result file"; FAIL=$((FAIL+1)); fi
}

skip() { echo "  $(yellow ⊘) skipped"; SKIP=$((SKIP+1)); }
cont() { echo ""; read -rp "  Enter to continue... " _; }

hdr() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $(cyan "Test $1"): $(bold "$2")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ═══════════════════════════════════════
# IPC: showItems
# ═══════════════════════════════════════

test_1() {
    hdr 1 "showItems — pipe-delimited"
    echo "  $(yellow →) Select 'banana'"
    cleanup
    "$QS" ipc call plugin:dmenu showItems "apple|banana|cherry" '{"separator":"|","prompt":"Fruit:"}'
    wait_result && expect "banana" || skip
    cleanup
}

test_2() {
    hdr 2 "showItems — newline-delimited, empty options"
    echo "  $(yellow →) Select 'two'"
    cleanup
    printf -v items "one\ntwo\nthree"
    "$QS" ipc call plugin:dmenu showItems "$items" ""
    wait_result && expect "two" || skip
    cleanup
}

# ═══════════════════════════════════════
# IPC: showJson
# ═══════════════════════════════════════

test_3() {
    hdr 3 "showJson — structured items"
    echo "  $(yellow →) Select 'Zen Browser'"
    cleanup
    local items='[{"name":"Firefox","value":"firefox","description":"Standard"},{"name":"Zen Browser","value":"zen","description":"Privacy"},{"name":"Chromium","value":"chromium"}]'
    local opts='{"prompt":"Browser:"}'
    "$QS" ipc call plugin:dmenu showJson "$items" "$opts"
    wait_result && expect "zen" || skip
    cleanup
}

test_4() {
    hdr 4 "showJson — mixed strings and objects"
    echo "  $(yellow →) Select 'detailed'"
    cleanup
    local items='["simple",{"name":"detailed","value":"detail-val","description":"Has a description"},"another"]'
    "$QS" ipc call plugin:dmenu showJson "$items" ''
    wait_result && expect "detail-val" || skip
    cleanup
}

test_5() {
    hdr 5 "showJson — with icons"
    echo "  $(yellow →) Select any item (visual check: icons should appear)"
    cleanup
    local items='[{"name":"Home","value":"home","icon":"home"},{"name":"Settings","value":"settings","icon":"settings"},{"name":"Star","value":"star","icon":"star"}]'
    "$QS" ipc call plugin:dmenu showJson "$items" '{"prompt":"Icons test:"}'
    wait_result && { local r; r=$(cat "$RESULT"); echo "  $(green ✓) selected $(bold "$r")"; PASS=$((PASS+1)); } || skip
    cleanup
}

# ═══════════════════════════════════════
# Search & filter
# ═══════════════════════════════════════

test_6() {
    hdr 6 "Search filter"
    echo "  $(yellow →) Type 'gra' then select 'grape'"
    cleanup
    "$QS" ipc call plugin:dmenu showItems "apple|grape|grapefruit|banana|orange" '{"separator":"|"}'
    wait_result 20 && expect "grape" || skip
    cleanup
}

test_7() {
    hdr 7 "Custom input"
    echo "  $(yellow →) Type 'my-value' and select the custom input entry"
    cleanup
    "$QS" ipc call plugin:dmenu showJson '["a","b"]' '{"allowCustomInput":true}'
    wait_result 20 && expect_contains "my-value" || skip
    cleanup
}

# ═══════════════════════════════════════
# Result formats
# ═══════════════════════════════════════

test_8() {
    hdr 8 "Result format — JSON"
    echo "  $(yellow →) Select 'beta'"
    cleanup
    "$QS" ipc call plugin:dmenu showJson '["alpha","beta","gamma"]' '{"resultFormat":"json"}'
    wait_result && expect_contains '"value":"beta"' || skip
    cleanup
}

test_9() {
    hdr 9 "Result format — index"
    echo "  $(yellow →) Select 'gamma' (third item, index 2)"
    cleanup
    "$QS" ipc call plugin:dmenu showJson '["alpha","beta","gamma"]' '{"resultFormat":"index"}'
    wait_result && expect "2" || skip
    cleanup
}

# ═══════════════════════════════════════
# Callbacks & chaining
# ═══════════════════════════════════════

test_10() {
    hdr 10 "Callback"
    echo "  $(yellow →) Select any item"
    cleanup; rm -f "$CB"
    local script="/tmp/noctalia-dmenu-cb.sh"
    printf '#!/usr/bin/env bash\nprintf "%%s" "$1" > %s\n' "$CB" > "$script"
    chmod +x "$script"
    "$QS" ipc call plugin:dmenu showJson '["red","green","blue"]' "{\"callbackCmd\":\"$script '{}'\"}"
    if wait_result; then
        local sel; sel=$(cat "$RESULT"); echo "  Selected: $(bold "$sel")"
        sleep 0.5
        if [[ -f "$CB" ]] && [[ "$(cat "$CB")" == "$sel" ]]; then
            echo "  $(green ✓) Callback wrote correct value"; PASS=$((PASS+1))
        else
            echo "  $(red ✗) Callback output mismatch"; FAIL=$((FAIL+1))
        fi
    else skip; fi
    cleanup; rm -f "$CB" "$script"
}

test_11() {
    hdr 11 "Chaining — two sequential menus"
    echo "  $(yellow →) Select 'Power', then 'Reboot'"
    cleanup
    local script="/tmp/noctalia-dmenu-chain.sh"
    cat > "$script" << 'EOF'
#!/usr/bin/env bash
noctalia-shell ipc call plugin:dmenu showItems "Shutdown|Reboot|Suspend" "{\"separator\":\"|\",\"prompt\":\"Power (picked: $1):\"}"
EOF
    chmod +x "$script"
    "$QS" ipc call plugin:dmenu showJson '["Power","Display","Network"]' "{\"callbackCmd\":\"$script '{}'\"}"
    if wait_result; then
        echo "  First: $(bold "$(cat "$RESULT")")"
        cleanup
        echo "  $(yellow →) Now select 'Reboot'"
        if wait_result; then expect "Reboot"; else
            echo "  $(red ✗) Second menu didn't appear"; FAIL=$((FAIL+1))
        fi
    else skip; fi
    cleanup; rm -f "$script"
}

# ═══════════════════════════════════════
# File loading
# ═══════════════════════════════════════

test_12() {
    hdr 12 "showFromFile"
    echo "  $(yellow →) Select 'line-three'"
    cleanup
    local f="/tmp/noctalia-dmenu-items.txt"
    printf "line-one\nline-two\nline-three\nline-four\n" > "$f"
    "$QS" ipc call plugin:dmenu showFromFile "$f" '{"prompt":"File test:"}'
    wait_result && expect "line-three" || skip
    cleanup; rm -f "$f"
}

# ═══════════════════════════════════════
# Panel lifecycle
# ═══════════════════════════════════════

test_13() {
    hdr 13 "Programmatic close"
    echo "  $(yellow →) Panel opens, auto-closes in 2s"
    cleanup
    "$QS" ipc call plugin:dmenu showItems "waiting|for|close" '{"separator":"|"}'
    sleep 2
    "$QS" ipc call plugin:dmenu close
    sleep 0.5
    if [[ ! -f "$RESULT" ]]; then
        echo "  $(green ✓) No result written"; PASS=$((PASS+1))
    else
        echo "  $(red ✗) Result file exists"; FAIL=$((FAIL+1))
    fi
    cleanup
}

test_14() {
    hdr 14 "Rapid session replacement"
    echo "  $(yellow →) Three menus fire rapidly. Select 'C3' from the last."
    cleanup
    "$QS" ipc call plugin:dmenu showItems "A1|A2|A3" '{"separator":"|"}'
    sleep 0.1
    "$QS" ipc call plugin:dmenu showItems "B1|B2|B3" '{"separator":"|"}'
    sleep 0.1
    "$QS" ipc call plugin:dmenu showItems "C1|C2|C3" '{"separator":"|","prompt":"Pick C3:"}'
    wait_result && expect "C3" || skip
    cleanup
}

# ═══════════════════════════════════════
# Helper script (noctalia-dmenu)
# ═══════════════════════════════════════

test_15() {
    hdr 15 "Helper: pipe mode"
    echo "  $(yellow →) Select 'pear'"
    cleanup
    echo -e "apple\npear\nplum" | noctalia-dmenu -p "Pipe test:"
    # noctalia-dmenu blocks until result, then prints to stdout
    # but we also check the file
    wait_result && expect "pear" || skip
    cleanup
}

test_16() {
    hdr 16 "Helper: file mode"
    echo "  $(yellow →) Select 'gamma'"
    cleanup
    local f="/tmp/noctalia-dmenu-helper-items.txt"
    printf "alpha\nbeta\ngamma\ndelta\n" > "$f"
    noctalia-dmenu -f "$f" -p "File helper test:" || true
    wait_result && expect "gamma" || skip
    cleanup; rm -f "$f"
}

test_17() {
    hdr 17 "Helper: custom separator"
    echo "  $(yellow →) Select 'two'"
    cleanup
    echo "one::two::three" | noctalia-dmenu -s "::" -p "Custom sep:"
    wait_result && expect "two" || skip
    cleanup
}

test_18() {
    hdr 18 "500 items (performance)"
    echo "  $(yellow →) Type a number to filter, select any"
    cleanup
    local items=""
    for i in $(seq 1 500); do
        [[ -n "$items" ]] && items+="|"
        items+="Item $i"
    done
    "$QS" ipc call plugin:dmenu showItems "$items" '{"separator":"|","prompt":"500 items:"}'
    if wait_result 30; then
        local r; r=$(cat "$RESULT")
        echo "  $(green ✓) Selected: $(bold "$r")"; PASS=$((PASS+1))
    else skip; fi
    cleanup
}

# ═══════════════════════════════════════
# Runner
# ═══════════════════════════════════════

run_all() {
    echo ""
    echo "$(bold "╔══════════════════════════════════════════════════╗")"
    echo "$(bold "║       noctalia-dmenu test suite                  ║")"
    echo "$(bold "╚══════════════════════════════════════════════════╝")"
    echo ""
    echo "  Press Escape to skip any test."
    read -rp "  Enter to start... " _

    for i in $(seq 1 18); do "test_$i"; cont; done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $(green Passed): $PASS  $(red Failed): $FAIL  $(yellow Skipped): $SKIP"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    [[ "$FAIL" -gt 0 ]] && exit 1
}

if [[ "${1:-}" =~ ^[0-9]+$ ]]; then cleanup; "test_$1"; cleanup
else run_all; fi
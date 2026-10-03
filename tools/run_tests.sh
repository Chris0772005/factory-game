#!/bin/bash
# Runs headless gameplay tests and the two-process network test.
# Usage: tools/run_tests.sh   (needs `godot` on PATH or GODOT env var)
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../game"
fail=0

echo "== Offline gameplay =="
timeout -s KILL 120 "$GODOT" --headless --path . res://tests/test_sandbox.tscn 2>&1 | grep -E "ok |FAIL|TESTS|SCRIPT ERROR" || fail=1

echo "== Network (host + client) =="
timeout -s KILL 100 "$GODOT" --headless --path . res://tests/test_net.tscn -- --host --role=host > /tmp/fg_host.log 2>&1 &
host_pid=$!
sleep 3
timeout -s KILL 90 "$GODOT" --headless --path . res://tests/test_net.tscn -- --join=127.0.0.1 --role=client > /tmp/fg_client.log 2>&1
wait $host_pid
grep -hE "^\[|SCRIPT ERROR" /tmp/fg_host.log /tmp/fg_client.log
grep -q "FAIL\|SCRIPT ERROR" /tmp/fg_host.log /tmp/fg_client.log && fail=1
exit $fail

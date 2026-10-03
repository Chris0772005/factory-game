#!/bin/bash
# Runs headless gameplay tests and the two-process network test.
# Usage: tools/run_tests.sh   (needs `godot` on PATH or GODOT env var)
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../game"
fail=0
# Random port so parallel test runs on one machine don't collide.
PORT=$((20000 + RANDOM % 20000))

echo "== Offline gameplay =="
timeout -s KILL 120 "$GODOT" --headless --path . res://tests/test_sandbox.tscn 2>&1 | grep -E "ok |FAIL|TESTS|SCRIPT ERROR" || fail=1

echo "== Factory simulation =="
timeout -s KILL 150 "$GODOT" --headless --path . res://tests/test_factory.tscn 2>&1 | grep -E "ok |FAIL|TESTS|stress|SCRIPT ERROR" || fail=1

echo "== Drawing, FX and foundry round =="
for t in test_drawing test_fx test_foundry; do
  timeout -s KILL 300 "$GODOT" --headless --path . res://tests/$t.tscn 2>&1 | grep -E "FAIL|TESTS|SCRIPT ERROR" || fail=1
done

echo "== Network (host + client) =="
timeout -s KILL 100 "$GODOT" --headless --path . res://tests/test_net.tscn -- --host --port=$PORT --role=host > /tmp/fg_host_$PORT.log 2>&1 &
host_pid=$!
sleep 3
timeout -s KILL 90 "$GODOT" --headless --path . res://tests/test_net.tscn -- --join=127.0.0.1 --port=$PORT --role=client > /tmp/fg_client_$PORT.log 2>&1
wait $host_pid
grep -hE "^\[|SCRIPT ERROR" /tmp/fg_host_$PORT.log /tmp/fg_client_$PORT.log
grep -q "FAIL\|SCRIPT ERROR" /tmp/fg_host_$PORT.log /tmp/fg_client_$PORT.log && fail=1

echo "== Network co-op foundry round =="
timeout -s KILL 160 "$GODOT" --headless --path . res://tests/test_net_foundry.tscn -- --host --port=$PORT --role=host > /tmp/fg_host2_$PORT.log 2>&1 &
host_pid=$!
sleep 4
timeout -s KILL 150 "$GODOT" --headless --path . res://tests/test_net_foundry.tscn -- --join=127.0.0.1 --port=$PORT --role=client > /tmp/fg_client2_$PORT.log 2>&1
wait $host_pid
grep -hE "^\[|SCRIPT ERROR" /tmp/fg_host2_$PORT.log /tmp/fg_client2_$PORT.log
grep -q "FAIL\|SCRIPT ERROR" /tmp/fg_host2_$PORT.log /tmp/fg_client2_$PORT.log && fail=1
exit $fail

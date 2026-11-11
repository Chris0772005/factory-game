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

echo "== Drawing, FX, foundry round, garage, bells, Eisenhalle =="
for t in test_drawing test_fx test_foundry test_garage test_bells test_iron_hall test_search test_scrap test_auto test_autofoundry; do
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
echo "== Network level change (host travels, client follows) =="
timeout -s KILL 120 "$GODOT" --headless --path . res://tests/test_net_travel.tscn -- --host --port=$PORT --role=host --no-save > /tmp/fg_host3_$PORT.log 2>&1 &
host_pid=$!
sleep 3
timeout -s KILL 110 "$GODOT" --headless --path . res://tests/test_net_travel.tscn -- --join=127.0.0.1 --port=$PORT --role=client --no-save > /tmp/fg_client3_$PORT.log 2>&1
wait $host_pid
grep -hE "^\[|SCRIPT ERROR" /tmp/fg_host3_$PORT.log /tmp/fg_client3_$PORT.log
grep -q "FAIL\|SCRIPT ERROR" /tmp/fg_host3_$PORT.log /tmp/fg_client3_$PORT.log && fail=1
grep -q "NET TRAVEL PASSED" /tmp/fg_client3_$PORT.log || fail=1
echo "== Network co-op garage round (bucket, quench, crate) =="
timeout -s KILL 150 "$GODOT" --headless --path . res://tests/test_net_garage.tscn -- --host --port=$PORT --role=host --no-save > /tmp/fg_host4_$PORT.log 2>&1 &
host_pid=$!
sleep 3
timeout -s KILL 140 "$GODOT" --headless --path . res://tests/test_net_garage.tscn -- --join=127.0.0.1 --port=$PORT --role=client --no-save > /tmp/fg_client4_$PORT.log 2>&1
wait $host_pid
grep -hE "^\[|SCRIPT ERROR" /tmp/fg_host4_$PORT.log /tmp/fg_client4_$PORT.log
grep -q "FAIL\|SCRIPT ERROR" /tmp/fg_host4_$PORT.log /tmp/fg_client4_$PORT.log && fail=1
grep -q "NET GARAGE PASSED" /tmp/fg_client4_$PORT.log || fail=1
echo "== Network co-op bell (profile, strickle, pour, dig out) =="
timeout -s KILL 160 "$GODOT" --headless --path . res://tests/test_net_bells.tscn -- --host --port=$PORT --role=host --no-save > /tmp/fg_host5_$PORT.log 2>&1 &
host_pid=$!
sleep 3
timeout -s KILL 150 "$GODOT" --headless --path . res://tests/test_net_bells.tscn -- --join=127.0.0.1 --port=$PORT --role=client --no-save > /tmp/fg_client5_$PORT.log 2>&1
wait $host_pid
grep -hE "^\[|SCRIPT ERROR" /tmp/fg_host5_$PORT.log /tmp/fg_client5_$PORT.log
grep -q "FAIL\|SCRIPT ERROR" /tmp/fg_host5_$PORT.log /tmp/fg_client5_$PORT.log && fail=1
grep -q "NET BELLS PASSED" /tmp/fg_client5_$PORT.log || fail=1
echo "== Network co-op Eisenhalle (tap, pattern, molding, two on the ladle wheel) =="
timeout -s KILL 170 "$GODOT" --headless --path . res://tests/test_net_iron.tscn -- --host --port=$PORT --role=host --no-save > /tmp/fg_host6_$PORT.log 2>&1 &
host_pid=$!
sleep 3
timeout -s KILL 160 "$GODOT" --headless --path . res://tests/test_net_iron.tscn -- --join=127.0.0.1 --port=$PORT --role=client --no-save > /tmp/fg_client6_$PORT.log 2>&1
wait $host_pid
grep -hE "^\[|SCRIPT ERROR" /tmp/fg_host6_$PORT.log /tmp/fg_client6_$PORT.log
grep -q "FAIL\|SCRIPT ERROR" /tmp/fg_host6_$PORT.log /tmp/fg_client6_$PORT.log && fail=1
grep -q "NET IRON PASSED" /tmp/fg_client6_$PORT.log || fail=1
echo "== Network Suchauftrag (host hides, client finds first) =="
timeout -s KILL 90 "$GODOT" --headless --path . res://tests/test_net_search.tscn -- --host --port=$PORT --role=host --no-save > /tmp/fg_host7_$PORT.log 2>&1 &
host_pid=$!
sleep 3
timeout -s KILL 80 "$GODOT" --headless --path . res://tests/test_net_search.tscn -- --join=127.0.0.1 --port=$PORT --role=client --no-save > /tmp/fg_client7_$PORT.log 2>&1
wait $host_pid
grep -hE "^\[|SCRIPT ERROR" /tmp/fg_host7_$PORT.log /tmp/fg_client7_$PORT.log
grep -q "FAIL\|SCRIPT ERROR" /tmp/fg_host7_$PORT.log /tmp/fg_client7_$PORT.log && fail=1
grep -q "NET SEARCH PASSED" /tmp/fg_client7_$PORT.log || fail=1
exit $fail

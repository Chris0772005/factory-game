#!/bin/bash
# Runs the headless gameplay tests and the two-process network tests.
# Usage: tools/run_tests.sh   (needs `godot` on PATH or GODOT env var)
#
# A test passes when it exits with 0, ends with its "... PASSED" line and its log holds no failed
# check, no script error and no signal that could not be delivered (both players' logs for the
# network tests). Other error lines of the engine are shown but do not fail the run. The exit code
# is 1 if any test did not pass.
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../game"
fail=0
# Random port so parallel test runs on one machine don't collide.
PORT=$((20000 + RANDOM % 20000))
BAD="FAIL|SCRIPT ERROR|Error calling from signal"
# Engine errors that are known and harmless (leftovers counted when the process ends).
KNOWN="resources still in use at exit"

# Shows the engine's other error lines of a log, so they are seen (they do not fail the run).
others() {
  grep -hE "^ERROR:" "$@" | grep -vE "$BAD|$KNOWN" | sort | uniq -c | sed 's/^/   (engine) /'
}

# offline <test> <seconds> <lines to show>
offline() {
  local log=/tmp/fg_$1_$PORT.log
  timeout -s KILL "$2" "$GODOT" --headless --path . "res://tests/$1.tscn" > "$log" 2>&1
  local status=$?
  grep -E "$3" "$log"
  others "$log"
  if [ $status -ne 0 ] || grep -qE "$BAD" "$log" || ! grep -q "TESTS PASSED" "$log"; then
    echo "   -> $1 did not pass (exit $status, log $log)"
    fail=1
  fi
}

# pair <test> <host seconds> <client seconds> <wait before the client> <pass line> [extra argument]
pair() {
  local host=/tmp/fg_$1_host_$PORT.log client=/tmp/fg_$1_client_$PORT.log
  timeout -s KILL "$2" "$GODOT" --headless --path . "res://tests/$1.tscn" -- --host --port=$PORT --role=host ${6:-} > "$host" 2>&1 &
  local host_pid=$!
  sleep "$4"
  timeout -s KILL "$3" "$GODOT" --headless --path . "res://tests/$1.tscn" -- --join=127.0.0.1 --port=$PORT --role=client ${6:-} > "$client" 2>&1
  wait $host_pid
  grep -hE "^\[|SCRIPT ERROR|Error calling from signal" "$host" "$client"
  others "$host" "$client"
  if grep -qE "$BAD" "$host" "$client" || ! grep -q "\[host\] $5 PASSED" "$host" || ! grep -q "\[client\] $5 PASSED" "$client"; then
    echo "   -> $1 did not pass (logs $host, $client)"
    fail=1
  fi
}

echo "== Offline gameplay =="
offline test_sandbox 120 "ok |FAIL|TESTS|SCRIPT ERROR"

echo "== Factory simulation =="
offline test_factory 150 "ok |FAIL|TESTS|stress|SCRIPT ERROR"

echo "== Drawing, FX, foundry round, garage, bells, Eisenhalle, scrap hall, quarter, crew, traffic, diner, shops =="
for t in test_drawing test_fx test_foundry test_garage test_bells test_iron_hall test_search test_scrap test_scrap_hall test_town test_missions test_auto test_autofoundry test_autoiron test_crew test_traffic test_diner test_shops; do
  offline $t 300 "FAIL|TESTS|SCRIPT ERROR"
done

echo "== Network (host + client) =="
pair test_net 100 90 3 "NET TESTS"
echo "== Network co-op foundry round =="
pair test_net_foundry 160 150 4 "NET FOUNDRY"
echo "== Network level change (host travels, client follows) =="
pair test_net_travel 120 110 3 "NET TRAVEL" --no-save
echo "== Network co-op garage round (bucket, quench, crate) =="
pair test_net_garage 150 140 3 "NET GARAGE" --no-save
echo "== Network co-op bell (profile, strickle, pour, dig out) =="
pair test_net_bells 160 150 3 "NET BELLS" --no-save
echo "== Network co-op Eisenhalle (tap, pattern, molding, two on the ladle wheel) =="
pair test_net_iron 170 160 3 "NET IRON" --no-save
echo "== Network Suchauftrag (host hides, client finds first) =="
pair test_net_search 90 80 3 "NET SEARCH" --no-save
echo "== Network quarter (client orders at the diner, sees the host's traffic) =="
pair test_net_town 150 140 3 "NET TOWN" --no-save
echo "== Network shops (client buys a tool and takes a loan, sees the host's sale at the stall) =="
pair test_net_shops 150 140 3 "NET SHOPS" --no-save
exit $fail

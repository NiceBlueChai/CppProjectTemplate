#!/bin/bash

cd "$(dirname "$0")"

BIN="./UnitTestFoo"

if [ ! -x "$BIN" ]; then
    chmod +x "$BIN"
fi

if [ "$1" == "--no-daemon" ]; then
    ./daemon --no-daemon
else
    nohup ./daemon > daemon.log 2>&1 &
    echo "daemon started in background. Output: daemon.log"
fi
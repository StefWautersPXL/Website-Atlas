#!/bin/bash

# Gebruik: ./bulk_manage.sh "192.168.1." 10 20 "uptime"
PREFIX=$1
START=$2
END=$3
COMMAND=$4

for i in $(seq -f "%02g" $START $END); do
    TARGET="${PREFIX}${i}"
    echo "--- Resultaat van $TARGET ---"
    ssh -o ConnectTimeout=5 root@$TARGET "$COMMAND"
    echo ""
done

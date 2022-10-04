#!/usr/bin/env bash

NAP=5

while true; do
    echo "Running vulnerability scan on $1"
    docker scan --json $1 |tee v.json

    echo "Checking results..."
    python3 build/check_scan_results.py scan_config.yml v.json |tee .vuln-res.tmp
    RET=${PIPESTATUS[0]}
    echo "Check finished with $RET"
    if [ $RET -eq 1 ] && grep -q 'JSONDecodeError' .vuln-res.tmp; then
        echo "Check failed with malformed JSON. Retrying in $NAP seconds."
    else
        exit $RET
    fi
    sleep $NAP
done

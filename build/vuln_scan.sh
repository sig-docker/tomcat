#!/usr/bin/env bash

NAP=5

while true; do
    echo "Running vulnerability scan on $1"
    docker scan --json $1 |tee v.json
    RET=${PIPESTATUS[0]}
    echo "Scan return code: $RET"
    if [ ! $RET -eq 0 ]; then
       echo "Error in scan process."
       exit 1
    fi

    echo "Checking results..."
    python3 build/check_scan_results.py scan_config.yml v.json 2> .vuln-res.tmp
    echo "--- STDERR ---"
    cat .vuln-res.tmp
    echo "--------------"
    RET=${PIPESTATUS[0]}
    echo "Check finished with $RET"
    if grep -q 'JSONDecodeError' .vuln-res.tmp; then
        echo "Check failed with malformed JSON. Retrying in $NAP seconds."
    else
        exit $RET
    fi
    sleep $NAP
done

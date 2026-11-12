#!/usr/bin/env bash
# Web server log analyzer (Apache/Nginx "combined" log format).
#
# Usage: ./scripts/log_analyzer.sh <logfile> [top_n]
#   logfile : path to an access log
#   top_n   : how many entries to show in the "top" lists (default 5)

LOG="${1:-}"
TOP="${2:-5}"

if [[ -z "$LOG" ]]; then
    echo "Usage: $0 <logfile> [top_n]" >&2
    exit 1
fi

if [[ ! -r "$LOG" ]]; then
    echo "Error: cannot read '$LOG'" >&2
    exit 1
fi

# Field numbers in the combined log format:
#   $1 = client IP, $7 = requested page, $9 = HTTP status code
total=$(wc -l < "$LOG")
not_found=$(awk '$9 == 404 { n++ } END { print n + 0 }' "$LOG")

echo "=============================================="
echo " Log analysis report: $LOG"
echo "=============================================="
echo "Total requests : $total"
echo "404 errors     : $not_found"
echo
echo "--- Requests by HTTP status code ---"
awk '{ print $9 }' "$LOG" | sort | uniq -c | sort -rn
echo
echo "--- Top $TOP most requested pages ---"
awk '{ print $7 }' "$LOG" | sort | uniq -c | sort -rn | head -n "$TOP"
echo
echo "--- Top $TOP IP addresses by number of requests ---"
awk '{ print $1 }' "$LOG" | sort | uniq -c | sort -rn | head -n "$TOP"
echo
echo "--- Pages that returned 404 ---"
awk '$9 == 404 { print $7 }' "$LOG" | sort | uniq -c | sort -rn | head -n "$TOP"

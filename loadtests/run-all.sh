#!/bin/bash
# Runs every scenario against every endpoint and saves a clean summary JSON per run.
# Uses --summary-export (not --out json) because it gives one aggregated file with
# real percentiles (p50/p90/p95/p99) instead of a raw per-request event stream —
# much easier to turn into the report table afterward.

set -e

mkdir -p results

# ---- fill in your real values from `terraform output` before running ----
LAMBDA_128_URL="https://sqw1gjia23.execute-api.us-east-1.amazonaws.com"
LAMBDA_1024_URL="https://1wuay3rrwc.execute-api.us-east-1.amazonaws.com"
FARGATE_URL="http://coffee-fargate-alb-607508141.us-east-1.elb.amazonaws.com"
EC2_URL="http://coffee-ec2-alb-662591559.us-east-1.elb.amazonaws.com"

# Parallel arrays instead of an associative array — same index in both arrays
# refers to the same endpoint.
NAMES=(lambda-128 lambda-1024 fargate ec2)
URLS=("$LAMBDA_128_URL" "$LAMBDA_1024_URL" "$FARGATE_URL" "$EC2_URL")

SUMMARY_STATS="avg,min,med,p(90),p(95),p(99),max"
SCENARIOS=(low-spiky medium-steady high-sustained)

for scenario in "${SCENARIOS[@]}"; do
  for i in "${!NAMES[@]}"; do
    name="${NAMES[$i]}"
    url="${URLS[$i]}"
    outfile="results/${name}-${scenario}.json"
    echo ""
    echo "=== Running $scenario against $name ($url) ==="
    k6 run \
      --summary-trend-stats="$SUMMARY_STATS" \
      --summary-export="$outfile" \
      -e TARGET_URL="$url" \
      "${scenario}.js"
    echo "Saved -> $outfile"
    sleep 10
  done
done

echo ""
echo "All runs complete. Results in ./results/"

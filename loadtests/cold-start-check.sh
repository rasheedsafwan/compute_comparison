#!/bin/bash
# Measures Lambda cold-start latency in isolation

URL="$1"   # pass the Lambda endpoint as an argument

if [ -z "$URL" ]; then
  echo "Usage: ./cold-start-check.sh <lambda-endpoint>"
  exit 1
fi

echo "=== COLD request (run this right after a fresh deploy/update) ==="
curl -s -o /dev/null -w "Total time: %{time_total}s\n" "$URL/coffee"

echo ""
echo "Now wait ~2-3 minutes, then run again for the WARM comparison:"
echo ""
echo "=== WARM request ==="
echo "(re-run: ./cold-start-check.sh $URL)"
curl -s -o /dev/null -w "Total time: %{time_total}s\n" "$URL/coffee"
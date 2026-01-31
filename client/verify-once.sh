#!/bin/bash
# PoI V2 Initial Verification
# Run this once to get your first credential

cd "$(dirname "$0")"
node cli.js verify

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Verification successful!"
  echo ""
  echo "To set up auto-maintenance, add to crontab:"
  echo "  crontab -e"
  echo ""
  echo "Add this line (runs every 12 hours):"
  echo "  0 */12 * * * cd ~/projects/proof-of-intelligence/client && node auto-maintain.js >> /tmp/poi-maintenance.log 2>&1"
else
  echo ""
  echo "❌ Verification failed. Check if still in cooldown."
  echo "Run: node cli.js status"
fi

#!/bin/sh

echo "🏁 Start Foundry Devnet"

# 100 accounts a day ago
anvil -a 100 --timestamp `date -r $(( $(date '+%s') - 86600 )) +%s` 



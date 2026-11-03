#!/bin/sh
# Puts the 0.16 store back, for use before 1.0 has taken any new mail: anything
# 1.0 received isn't in this store. After that, use stalwart-migrate rollback.
set -eu
cd /data
[ -d data-0.16 ] && [ -d etc-0.16 ] || { echo "no 0.16 store to put back"; exit 1; }
mv data data-v1.reverted
mv etc etc-v1.reverted
mv data-0.16 data
mv etc-0.16 etc
echo "done: roll the service back to its last 0.16.27 deployment."

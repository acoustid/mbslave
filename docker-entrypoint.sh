#!/bin/bash
set -e

if [ "$KEEP_ALIVE" = "1" ] || [ "$KEEP_ALIVE" = "true" ] || [ $# -eq 0 ]; then
    echo "KEEP_ALIVE is set or no command provided, staying up..."
    # Keep the container running
    tail -f /dev/null
else
    exec "$@"
fi

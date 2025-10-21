#!/bin/bash
set -e

# Add Spark jars to classpath
export SPARK_CLASSPATH="/opt/spark/jars/*"

is_interactive() {
    [ -t 0 ] && [ -t 1 ]
}

if [ "$1" = "spark-submit" ]; then
    shift
    spark-submit "$@"
    echo "Spark job completed."

    if is_interactive; then
        echo "Dropping into interactive shell..."
        exec /bin/bash
    else
        echo "Keeping container alive (non-interactive mode)..."
        exec tail -f /dev/null
    fi
else
    if is_interactive; then
        echo "Starting interactive Spark shell..."
        exec /bin/bash
    else
        echo "Spark container running in background..."
        exec tail -f /dev/null
    fi
fi
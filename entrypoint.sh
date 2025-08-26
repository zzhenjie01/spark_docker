#!/bin/bash
set -e

# Add Spark jars to classpath
export SPARK_CLASSPATH="/opt/spark/jars/*"

# Default command
if [ "$1" = "spark-submit" ]; then
    exec "$@"
else
    exec /bin/bash
fi
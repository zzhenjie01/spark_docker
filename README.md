# Spark Docker

## Getting Started

1. Clone Repository

    `cd` into desired local directory. Then, run

    ```bash
    git clone https://github.com/zzhenjie01/spark_docker.git
    ```

2. Build Image

    ```bash
    docker build -t spark-pyspark:3.3.4 .
    ```

3. Run `spark-submit` with local script on Standalone mode

    Mount local directory and run spark-submit

    ```bash
    docker run -it --rm \
    -v $(pwd):/app \
    spark-pyspark:3.3.4 \
    spark-submit \
    --master 'local[*]' \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.3.4,com.datastax.spark:spark-cassandra-connector_2.12:3.4.1 \
    /app/example_job.py
    ```

4. Interactive development shell

    Start an interactive container with your code mounted.

    ```bash
    docker run -it --rm \
    -v $(pwd):/app \
    -p 4040:4040 \
    spark-pyspark:3.3.4 \
    /bin/bash
    ```

    Inside container, you can run:

    ```bash
    spark-submit /app/example_job.py
    ```

5. For production deployments

    Build with specific network settings and resource limits

    ```bash
    docker run -d \
    --name spark-prod \
    --memory=4g \
    --cpus=2 \
    -v $(pwd):/app \
    spark-pyspark:3.3.4 \
    spark-submit \
    --master 'local[*]' \
    --executor-memory 2g \
    /app/example_job.py
    ```
    

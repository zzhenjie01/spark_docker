# Spark Docker

## Getting Started

1. Clone Repository

    `cd` into desired local directory. Then, run

    ```bash
    git clone https://github.com/zzhenjie01/spark_docker.git
    ```

2. Build Image

    ```bash
    docker build -t spark-pyspark:3.5.1 .
    ```

3. Run `spark-submit` with local script on Standalone mode

    Mount local directory and run `spark-submit`.

    ```bash
    docker run -it --rm \
    -v $(pwd):/app \
    spark-pyspark:3.5.1 \
    spark-submit \
    --master 'local[*]' \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1,com.datastax.spark:spark-cassandra-connector_2.12:3.5.1 \
    /app/example_job.py
    ```

    Note that we need to wrap the `local[*]` in single quotes. This is because in zsh (and bash), the `*` character is a wildcard that gets expanded to match files in the current directory. `zsh` will try to find files that match the pattern `local[*]` in your current directory before passing the arguments to Docker. Since no files match this pattern, `zsh` will throw an error.

    Also note that Spark Cassandra Connector version 3.3.4 doesn't exist. The version numbering for the Cassandra connector doesn't exactly match the Spark version. So need to check on [Maven repository](https://mvnrepository.com/artifact/com.datastax.spark/spark-cassandra-connector). For Spark 3.3.4, you should use Cassandra Connector 3.4.1.

    Note that when we use `--packages` with `spark-submit` inside a container, the dependencies are downloaded to the container's internal filesystem, not to a Docker volume. Specifically, Spark downloads the packages to `/root/.ivy2/` inside the container's temporary filesystem. The `.ivy2` folder is in the container's writable layer (not a mounted volume). When the container exits, this writable layer is destroyed.

4. Interactive development shell

    Start an interactive container with your code mounted.

    ```bash
    docker run -it --rm \
    -v $(pwd):/app \
    -p 4040:4040 \
    spark-pyspark:3.5.1 \
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
    spark-pyspark:3.5.1 \
    spark-submit \
    --master 'local[*]' \
    --executor-memory 2g \
    /app/example_job.py
    ```

6. Run `spark-submit` with local script on Standalone mode with `.conf` file

    Mount local directory and run spark-submit with `.conf`. We have to mount the local `.conf` file during runtime as well.

    ```bash
    docker run -it --rm \
    -v $(pwd):/app \
    -v $(pwd)/spark-defaults.conf:/opt/spark/conf/spark-defaults.conf \
    spark-pyspark:3.5.1 \
    spark-submit \
    /app/example_job.py
    ```

## Documentation

### `Dockerfile`

```Dockerfile
FROM eclipse-temurin:17-jre-jammy
```

- The base image with Temurin Java 17 is built on Ubuntu 22.04
- Only the JRE is needed for running the Spark application

```Dockerfile
RUN wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && tar xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark \
    && rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz
```

- We download Spark tarball file here so that we don't have to keep rebuilding images, if we decide to modify subsequent layers of the image.
- Another reason is that this step is the slowest as the tarball file is ~308MB.
- Furthermore, Spark will impose throttling of download speed to prevent abuse and DDoS of their download service if they detect heavy use. [StackOverflow](https://stackoverflow.com/questions/68487404/are-downloads-from-spark-distribution-archive-often-slow).
- Also, we can only download from the archive link instead of the mirror (which is faster) because mirror only contains the latest tarball and not the older ones.

```Dockerfile
# Copy Spark tarball from local filesystem
COPY spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz /tmp/

# Install Spark from local tarball
RUN tar xzf /tmp/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark \
    && rm /tmp/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz
```

- Alternatively, we could download Spark tarball to local directory using browser which is much faster and copy over when building the image.

```Dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        build-essential \
        python${PYTHON_VERSION} \
        python3-dev \
        python3-pip \
        unixodbc \
        unixodbc-dev \
        freetds-bin \
        freetds-dev \
        tdsodbc \
        gdal-bin \
        libgdal-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

- `wget` is included in Ubuntu 22.04 by default, but not `curl`.
- Technically, Ubuntu 22.04 has Python 3.10 by default, but we install it explicitly.
- Although Python 3.10 is default in Ubuntu 22.04, it does not include `pip` by default.
- `apt-get update`: updates the package index so the container knows the latest versions of packages available.
- `apt-get install -y --no-install-recommends`: installs required packages without pulling in optional “recommended” ones to keep the image smaller.
  - `curl`: for downloading files from the internet (used later to fetch Spark connectors).
  - `build-essential`: provides compiler tools (gcc, g++, make, etc.) needed to compile Python packages with C/C++ extensions.
  - `python${PYTHON_VERSION}`: installs the specified Python version (e.g. Python 3.10).
  - `python3-dev`: headers and development libraries for building Python modules.
  - `python3-pip`: installs `pip` to manage Python packages.
  - `unixodbc`, `unixodbc-dev`, `freetds-bin`, `freetds-dev`, `tdsodbc`: ODBC and FreeTDS drivers/libraries for connecting Spark/Python to relational databases like MSSQL.
  - `gdal-bin`, `libgdal-dev`: GDAL tools and libraries for working with geospatial data (useful if Spark jobs handle GIS datasets).
- `apt-get clean` & `rm -rf /var/lib/apt/lists/*`: cleanup steps to remove package cache and metadata to reduce image size.

```Dockerfile
RUN ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3
```

- Makes `/usr/bin/python` and `/usr/bin/python3` point to installed python3.10
- Need to use `ln -sf` to force the link creation because in Ubuntu 22.04, the default `python3` package is Python 3.10.
- But there is no unversioned `python` command by default (only `python3` exists)

```Dockerfile
ENV SPARK_HOME=/opt/spark
ENV PATH=$SPARK_HOME/sbin:$SPARK_HOME/bin:$PATH
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-*-src.zip
ENV PYSPARK_PYTHON=python
ENV PYSPARK_DRIVER_PYTHON=python
ENV SPARK_NO_DAEMONIZE=true
```

- No need to set `JAVA_HOME` and add Java binary to `PATH` because the base image already has it.
- Both `/bin` and `/sbin` directories store executable programs. `/bin` contains essential binaries for basic system operations accessible to all users, while `/sbin` contains binaries primarily for system administration tasks, often restricted to the root user.
- Note that the `py4j` version should match our Spark version and we use wildcard to avoid versioning issues.
- PySpark is a wrapper around Spark. `PYTHONPATH` tells Python where to find these wrapper files that bridge the two worlds. `pyspark` is the Python package that allows you to interact with Spark. `py4j` bridge is a special library that lets Python code call Java methods. 
- `$SPARK_HOME/python` contains the actual pyspark Python package. Without this, `import pyspark` would fail completely and this is where all the Python classes like SparkSession, DataFrame live.
- `$SPARK_HOME/python/lib/py4j-*-src.zip` contains the py4j library (the Java-Python bridge) which allows Python code to make calls like `df.show()` which actually get executed in the Java Spark engine. Without this, you could `import pyspark` but nothing would work.

```Dockerfile
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt
```

- `COPY requirements.txt /tmp/requirements.txt` copies your local `requirements.txt` file into the image.
- `pip3 install --no-cache-dir -r /tmp/requirements.txt` installs all Python dependencies listed in `requirements.txt`.
  - `--no-cache-dir` prevents pip from storing downloaded packages in a local cache, reducing image size.
- `rm /tmp/requirements.txt` deletes the file after installation to avoid leaving unnecessary files inside the image.

```Dockerfile
RUN mkdir -p /opt/spark/jars

RUN curl -L -o /opt/spark/jars/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar

RUN curl -L -o /opt/spark/jars/spark-cassandra-connector_${SCALA_VERSION}-${SPARK_VERSION}.jar \
    https://repo1.maven.org/maven2/com/datastax/spark/spark-cassandra-connector_${SCALA_VERSION}/${SPARK_VERSION}.jar

RUN curl -L -o /opt/spark/jars/mssql-jdbc-12.4.1.jre11.jar \
    https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.4.1.jre11/mssql-jdbc-12.8.1.jre11.jar
```

- When we run this commands, the JAR files became part of the read-only image layers of our image. They're baked into the image itself at `/opt/spark/jars/`. There are no volumes created. Volumes are only used for persistent data that needs to survive container restarts or be shared between containers.

```Dockerfile
WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
```

- `WORKDIR /app` sets `/app` as the working directory inside the container. All subsequent commands (like `COPY`, `RUN`, or `CMD`) will use this as the default directory. If you `docker exec` into the container, you’ll also land here by default.
- `COPY entrypoint.sh /entrypoint.sh` copies your `entrypoint.sh` script from the host machine into the container’s root directory.
- `RUN chmod +x /entrypoint.sh` makes the script executable.
- `ENTRYPOINT ["/entrypoint.sh]` defines the container’s *entrypoint*. This means whenever the container starts, it will always execute `/entrypoint.sh`.


### `entrypoint.sh`

```bash
#!/bin/bash
set -e
```

- The `#!/bin/bash` on the first line of the script tells the shell what interpreter to use while executing the script. In this case, the script should be interpreted and executed by `bash` shell.
- `set -e` makes the script exit immediately if any command fails which prevents continued execution when there are errors.

```bash
export SPARK_CLASSPATH="/opt/spark/jars/*"
```

- Adds all the JAR files we downloaded (Kafka, Cassandra, MSSQL connectors) to Spark's classpath which is essential for Spark to recognize and use these connectors.

```bash
if [ "$1" = "spark-submit" ]; then
    exec "$@"
else
    exec /bin/bash
fi
```

- If you run `spark-submit`, it executes your Spark job directly.
- If you run anything else, it drops you into a bash shell for interactive work
- This allows the container to be used both for job execution and development.
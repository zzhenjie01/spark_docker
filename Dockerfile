# Use a base image with Temurin Java 17 built on Ubuntu 22.04
# Only the JRE is needed for running the Spark application
FROM eclipse-temurin:17-jre-jammy

# Use ARG for build-time variables
ARG PYTHON_VERSION=3.10
ARG SPARK_VERSION=3.3.4
ARG HADOOP_VERSION=3
ARG SCALA_VERSION=2.12
ARG PYSPARK_VERSION=3.3.4

# Install Spark here so that no need keep downloading when rebuilding image
RUN wget -q --user-agent="Docker-Spark-Build/1.0" https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && tar xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark \
    && rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz

# Install system dependencies and tools
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

# Create symbolic link for the installed python3.10
RUN ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3

# Set environment variables
ENV SPARK_HOME=/opt/spark
ENV PATH=$SPARK_HOME/sbin:$SPARK_HOME/bin:$PATH
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-*-src.zip
ENV PYSPARK_PYTHON=python
ENV PYSPARK_DRIVER_PYTHON=python
ENV SPARK_NO_DAEMONIZE=true

# Install Python dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Install JDBC drivers and connectors
RUN mkdir -p /opt/spark/jars

# Download Kafka Spark connector
RUN curl -L -o /opt/spark/jars/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar

# Download Cassandra Spark connector
RUN curl -L -o /opt/spark/jars/spark-cassandra-connector_${SCALA_VERSION}-${SPARK_VERSION}.jar \
    https://repo1.maven.org/maven2/com/datastax/spark/spark-cassandra-connector_${SCALA_VERSION}/${SPARK_VERSION}/spark-cassandra-connector_${SCALA_VERSION}-${SPARK_VERSION}.jar

# Download MSSQL JDBC driver
RUN curl -L -o /opt/spark/jars/mssql-jdbc-12.4.1.jre11.jar \
    https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.4.1.jre11/mssql-jdbc-12.4.1.jre11.jar

# Create working directory
WORKDIR /app

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

def main():
    spark = SparkSession.builder \
        .appName("ExampleSparkJob") \
        .config("spark.jars", "/opt/spark/jars/*") \
        .config("spark.sql.adaptive.enabled", "true") \
        .getOrCreate()

    # Example: Read from Kafka
    # kafka_df = spark.read \
    #     .format("kafka") \
    #     .option("kafka.bootstrap.servers", "kafka-server:9092") \
    #     .option("subscribe", "topic-name") \
    #     .load()

    # Example: Read from MSSQL
    # mssql_df = spark.read \
    #     .format("jdbc") \
    #     .option("url", "jdbc:sqlserver://server:port;databaseName=db") \
    #     .option("dbtable", "table") \
    #     .option("user", "user") \
    #     .option("password", "password") \
    #     .load()

    # Example: Write to Cassandra
    # df.write \
    #     .format("org.apache.spark.sql.cassandra") \
    #     .option("keyspace", "keyspace") \
    #     .option("table", "table") \
    #     .mode("append") \
    #     .save()

    # Simple example with local data
    data = [("Alice", 1), ("Bob", 2), ("Charlie", 3)]
    df = spark.createDataFrame(data, ["Name", "Value"])
    df.show()

    spark.stop()

if __name__ == "__main__":
    main()
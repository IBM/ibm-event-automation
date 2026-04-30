
This repository contains examples and samples that demonstrate how to use Flink User-Defined Functions (UDF) such as [Scalar Functions(https://nightlies.apache.org/flink/flink-docs-release-1.18/docs/dev/table/functions/udfs/#scalar-functions) and [Table Functions](https://nightlies.apache.org/flink/flink-docs-release-1.18/docs/dev/table/functions/udfs/#table-functions).

## Prerequisites

- Java 11
- Java Integrated Development Environment (IDE)
- [Docker](https://github.com/docker/compose/releases) version 2.24.5 or later 

## Deploying and running the functions on a Flink cluster

Find out how to run the UDFs on a Flink cluster by using a Java IDE or the docker compose. 

### By using a Java IDE

Each UDF example contains a Java class with a main entry point that uses the Flink Table API, to quickly execute the function and view the output as text:

- For scalar functions: `com.ibm.flink.udf.scalar.StandaloneDryRun.java` 

- For table functions: `com.ibm.flink.udf.table.StandaloneDryRun.java`

These classes can be executed directly in a Java IDE without setting up a Flink cluster.


### By using docker compose

Each UDF example can be tested by using a dedicated SQL sample file:

- For scalar functions: `scalar-function-udf.sql`

- For table functions: `table-function-udf.sql`

### Procedure

Complete the following steps to test your UDF:

1. Prepare a custom Flink docker image augmented with the UDF JAR.

   1. Build the JAR file containing the UDF.
   
   ```shell
   build-maven-project.sh
   ```
   
   2. Build a docker image 'flink-with-udf:latest' with the JAR file containing the UDF:

      1. Determine the IBM Flink image using the procedure at step 1.a of [Build and deploy a Flink SQL runner](https://ibm.github.io/event-automation/ep/advanced/deploying-production/#build-and-deploy-a-flink-sql-runner). In the following, this image is referred to as `IBM_FLINK_IMAGE`.

      2. Execute the following by replacing the placeholder `<IBM_FLINK_IMAGE>` by the actual name.

         ```shell
         build-flink-image.sh <IBM_FLINK_IMAGE>
         ```

2. Start the Flink cluster with the augmented Flink docker image:

   ```shell
   flink-cluster.sh start
   ```

3. Execute the SQL statement for the user-defined function that you want to test:

   - To use a scalar function:

   ```shell
   flink-cluster.sh run sql/scalar-function-udf.sql
   ```

   - To use a table function:

   ```shell
   flink-cluster.sh run sql/table-function-udf.sql
   ```

4. Stop the Flink cluster by running the following command:

   ```shell
   flink-cluster.sh stop
   ```
   


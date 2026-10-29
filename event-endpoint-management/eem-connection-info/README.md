# eem-connection-info

`eem-connection-info.sh` gets the bootstrap servers and the CA certificate that a Kafka client
needs to connect to a virtual topic through the gateways of a gateway group.

The Catalog in the Event Endpoint Management UI shows them for the external endpoints only. Use this
script to get the **internal** ones, for Kafka clients that run in the same cluster as the gateways.
The script returns the external ones too.

## Prerequisites

Before you run the script, ensure the following:

- Event Endpoint Management version 11.9.1 or later.
- `bash`, `curl` and `jq`.
- From the Event Endpoint Management UI, under **Profile** > **Access tokens**:
  - The **Admin API URL**.
  - The root certificate (click **Download root certificate**).
  - An access token (click **Create token**).
- The source topic name, the virtual topic alias and the gateway group name, as shown in the Catalog.

## Usage

```sh
./eem-connection-info.sh \
  --url           <admin-api-url> \
  --cacert        <root-certificate.pem> \
  --token         <access-token> \
  --topic         <source-topic> \
  --virtual-topic <alias> \
  --gateway-group <group-name> \
 [--output-dir    <directory>]
```

Run `./eem-connection-info.sh --help` for more details.

## Output

The script writes these files and prints the matching Kafka client properties:

```
<output-dir>/
  internalEndpoints/
    bootstrap-server.txt
    ca.pem
  endpoints/
    bootstrap-server.txt
    ca.pem
```

Use the files in `internalEndpoints/` for Kafka clients that run in the same cluster as the gateways.
Use the files in `endpoints/` for all other clients.
Set these properties to configure the Kafka client:

```properties
bootstrap.servers=<content of bootstrap-server.txt>
ssl.truststore.location=<path to ca.pem>
ssl.truststore.type=PEM
```


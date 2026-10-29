# eem-connection-info

The `eem-connection-info.sh` script retrieves the bootstrap servers and the CA certificate that a Kafka client requires to connect to a virtual topic through the gateways in a gateway group.

The Catalog in the Event Endpoint Management UI displays the bootstrap servers and CA certificate only for the external endpoints. For Kafka clients that run in the same cluster as the gateways, use this script to obtain the bootstrap servers and CA certificate for the internal endpoints. The script also returns the external endpoint values.

## Prerequisites

Before you run the script, ensure meet the following prerequisites:

- Event Endpoint Management version 11.9.1 or later installed.
- `bash`, `curl` and `jq` installed.
- Obtain the following from the Event Endpoint Management UI, under **Profile** > **Access tokens**:
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

The script writes the following files to the output directory and prints the matching Kafka client properties:

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


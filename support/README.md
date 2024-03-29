# Must Gather Support Tool


This directory hosts the tooling you should use for collecting diagnostic information
to supply to IBM when opening an IBM support case for one of the IBM Event Automation capabilities.

## Recommended Must Gather

The `ibm-events-must-gather` script can be used to collect diagnostic information for all
the IBM Event Automation capabilities either individually or collectively depending on the
parameters specified when running the script.

A pod will be deployed on your cluster into a dedicated namesapce and diagnostic information collected before being transferred
to your local filesystem.  This script requires you to have cluster admin privileges and minimises the number of times we may
have to ask for more diagnostics to be manually collected.

For information on running the script see the [gathering logs documentation.](https://ibm.biz/ea-gather-logs).


## Restricted Must Gather

If you do not have cluster admin privileges, then you can run the `restricted-must-gather.sh` script to attempt 
collecting reduced diagnostic information via remote `kubectl` calls to your cluster.

- The bash script requires `openssl`, `kubectl` and `jq` installed to run.
- You must be logged into your cluster using either the `kubectl config use-context` or `oc login` commands.
- Output will be captured in a directory called `restricted-must-gather-<DATE-TIMESTAMP>`, you should compress this directory and supply the resultant file on your support case.

```shell
Usage:
  restricted-must-gather.sh [flags]

Options:
  -m|--modules'': Define the data module that specifies what type of information is collected. For more information, see Available data modules.
  -n|--namespace'': Specify the namespace from which the data is collected.  If specifying more than one of eventstreams, eem, eventprocessing and flink modules, individual namespace flags must be used
  --es-namespace'': the namespace from which the eventstreams data is collected.
  --eem-namespace'': the namespace from which the eem data is collected.
  --ep-namespace'': the namespace from which the eventprocessing data is collected.
  --flink-namespace'': the namespace from which the flink data is collected.
  -h|--help: Display the help message.

Available data modules:
  eventstreams            Resources relating to instances of eventstreams
                          Resources relating to the eventstreams operator
                          Resources relating to instances of kafka connect
  eventprocessing         Resources relating to instances of event processing
                          Resources relating to the event processing operator
  eem                     Resources relating to instances of event endpoint management
                          Resources relating to the event endpoint management operator
  flink                   Resources relating to instances of flink
                          Resources relating to the flink operator

Specifying namespaces:
  If only one module is specified in the list of modules, you simply specify the relevant namespace
  using the -n|--namespace flag.

  If multiple products are being specified, then you MUST utilise the individual namespace flags for each module:

    --es-namespace'': the namespace from which the eventstreams data is collected.
    --eem-namespace'': the namespace from which the eem data is collected.
    --ep-namespace'': the namespace from which the eventprocessing data is collected.
    --flink-namespace'': the namespace from which the flink data is collected.
```

#### Examples:

```shell
# Gathering restricted Event Endpoint Management diagnostics for an instance running in the 'myeem' namespace
./restricted-must-gather.sh -m eem -n myeem

# Gathering restricted Event Processing and Flink diagnostics for an instances running in the 
# 'myepns' namespace and 'myflinkns' respectively
./restricted-must-gather.sh -m eventprocessing,flink --ep-namespace myepns --flink-namespace myflinkns
```


## Manual Diagnostic Collection

If you are experiencing problems with using either the recommended must gather tooling or the restricted must gather
script, please try to capture and supply relevant resources from your cluster pertaining to the problem you are experiencing.

As a minimum, please provide relevant operator and instance pod logs along with the instance custom resource (CR).

#### Useful commands:

```shell
# Capture a listing of all pods in the namespace
kubectl get pods -n <INSTANCE_NAMESPACE> -o wide >> pod-list.log

# Capture detailed output about the state of all pods in the namespace
kubectl get pods -n <INSTANCE_NAMESPACE> -o yaml >> pod-details.log

# Capture individual pod logs, you should capture both the operator and pods related to the instance
# remember your operator pod might be in a different namespace
kubectl logs <POD_NAME> -n <INSTANCE_NAMESPACE> >> <POD_NAME>.log

# Capture eventstreams instances and status
kubectl get eventstreams -n <EVENTSTREAMS_INSTANCE_NAMESPACE> -o yaml >> all-eventstreams-details.log

# Capture eventprocessing instances and status
kubectl get eventprocessings -n <EVENTPROCESSING_INSTANCE_NAMESPACE> -o yaml >> all-eventprocessing-details.log

# Capture flinkdeployment instances and status
kubectl get flinkdeployments -n <FLINKDEPLOYMENT_INSTANCE_NAMESPACE> -o yaml >> all-flinkdeployments-details.log

# Capture eventendpointmanagement instances and status
kubectl get eventendpointmanagements -n <EEM_INSTANCE_NAMESPACE> -o yaml >> all-eems-details.log

# Capture eventgateway instances and status
kubectl get eventgateways -n <EGW_INSTANCE_NAMESPACE> -o yaml >> all-egws-details.log
```

It is highly likely the support team will ask you to collect further diagnostic information.
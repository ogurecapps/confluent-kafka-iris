# Apache Kafka adapters for the InterSystems IRIS Data Platform
If you have seen the default platform adapters for Kafka in the package `EnsLib.Kafka.*`, you might have noticed that this implementation looks a bit like a proof of concept. It does not support partitions, non-auto offset, and does not translate Java errors to the IRIS level... So, this project is an attempt to create more flexible IRIS connectors for Apache Kafka, based on the `confluent-kafka-python` library.

Of course, it is not a universal solution. I believe that making connectors, considering all possible cases, would make the settings of adapters overcomplicated. So it is a base, which you can feel free to fork and improve according to your requirements.

This project is backward-compatible with the default implementation. It means the same settings for business hosts, so you can just change the class name in Production. If you are already using `EnsLib.Kafka.Service` - change class to `Kafka.Service.Consumer`, and for `EnsLib.Kafka.Operation` change to `Kafka.Operation.Producer`.

One of the additional features of the project - common settings storage for adapters through the [Lookup Tables](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=ECONFIG_lookup_tables) mechanism. Both adapters have a setting called `ConfigLookupTable`, which specifies the name of the table containing the parameter key-values. Therefore, you can utilize all configuration parameters available in the official documentation (for both [consumers](https://docs.confluent.io/platform/current/installation/configuration/consumer-configs.html) and [producers](https://docs.confluent.io/platform/current/installation/configuration/producer-configs.html)). Keep in mind, some of these may require changes to the code. Additionally, it helps avoid repeating all settings in each service or operation when reading or writing different partitions, for example.

The inbound adapter implements guaranteed delivery (see the checkbox `AtLeastOnce`). When enabled, IRIS will update the message offset in Kafka only after receiving a non-failure response from the target Business Host(s). It means repeatedly pulling the same Kafka message until the message is successfully delivered to its target.

## How it run
You must have installed [Docker Desktop](https://www.docker.com/products/docker-desktop) and [Git](https://git-scm.com) on your local PC. Clone the repository and run Docker containers:
```
git clone https://github.com/ogurecapps/confluent-kafka-iris.git
cd confluent-kafka-iris
docker-compose up -d
```
Interoperability Production will be available on the URL (use default credentials `_system` `SYS` for login): `http://localhost:52774/csp/dev/EnsPortal.ProductionConfig.zen?$NAMESPACE=DEV`

IRIS Production has a service called `Sample.Service.MessageGenerator`: this service generates 2 messages (by default, every 1 hour) and puts them into partitions numbers 0 and 1 of the Kafka topic named `test`.

The next one is `Kafka.Service.Consumer.Part1`, it reads partition 1 of the `test` topic (every 5 sec). You can change the `AtLeastOne` option, enable log trace events, or enable the `ThrowError` flag in `Sample.Process.MessageHandler` to watch how it works in different scenarios.

Furthermore, the project has deployed Kafka UI. You can check topics, messages, consumers, and so on via the UI available at: `http://localhost:8080` (no need for authorization).

## Known issues
Sometimes, the first run of the Consumer service causes a `Broker: Not coordinator` error. It is not related time passed from deploying Kafka or the topic creation... This error is gone after the business service restart. If somebody knows how to fix it, please feel free to message me. 
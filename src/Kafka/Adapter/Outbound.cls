/// Use confluent-kafka-python library
Class Kafka.Adapter.Outbound Extends (Kafka.Adapter.Common, Ens.OutboundAdapter)
{

/// The Kafka topic (can override in the message)
Property Topic As %String(MAXLEN = 100);

/// The partition to send to
Property Partition As %Integer [ InitialExpression = 0 ];

/// Kafka client ID
Property ClientID As %String(MAXLEN = 100) [ InitialExpression = {"IRIS-"_$NAMESPACE} ];

/// You can use this lookup table as a common storage for default configs for Producers. 
/// It is needed not to repeat all settings in each operation when we write to different partitions, for example.
/// Also, to this table, you can add parameters which not defined as Business Host Settings (full list of parameters available here: 
/// https://docs.confluent.io/platform/current/installation/configuration/producer-configs.html).
/// Business Host Settings (Servers, Credentials, ClientID, etc.) will redefine parameters from the ConfigLookupTable.
Property ConfigLookupTable As %String [ InitialExpression = "Kafka.ProducerConfigs" ];

/// The Kafka Producer
Property Producer As %SYS.Python [ Private ];

/// Needed for forward error from the callback to the IRIS level
Property ProduceError As %String [ Private ];

Parameter SETTINGS = "Topic:Kafka Settings,Partition:Kafka Settings,ClientID:Kafka Settings,ConfigLookupTable:Kafka Settings";

/// Create the Kafka client here
Method OnInit() As %Status
{
	Set tSC = ..GetConfDict(..ConfigLookupTable, .config)
	Return:$$$ISERR(tSC) tSC

	Do ..OverrideByLocal(.config)
	Do:..ClientID'="" config.setdefault("client.id", ..ClientID)

	Try {Do ..CreateKafkaClient(config)} Catch ex {Set tSC = ex.AsStatus()}
	
	Return tSC
}

/// Destroy the Kafka client here
Method OnTearDown() As %Status
{
	Set tSC = $$$OK
	Try {Do ..DestroyKafkaClient()} Catch ex {Set tSC = ex.AsStatus()}

	Return tSC
}

Method CreateKafkaClient(config As %SYS.Python) [ Language = python ]
{
	if config['bootstrap.servers'] == '':
		raise KafkaException('No Kafka servers configured (check \'bootstrap.servers\' in ConfigLookupTable or \'Servers\' in settings of Operation)')

	self.Producer = Producer(config)
}

Method DestroyKafkaClient() [ Language = python ]
{
	self.Producer.close()
}

Method Produce(request As EnsLib.Kafka.Message) As %Status
{
	Set tSC = $$$OK
	Try {Do ..ProduceImpl(request)} Catch ex {Set tSC = ex.AsStatus()}

	Return tSC
}

Method ProduceImpl(request As EnsLib.Kafka.Message) [ Language = python ]
{
	topic = request.topic if (request.topic != '') else self.Topic
	if topic == '':
		raise KafkaException('No Kafka topic provided')

	self.ProduceError = ''
	
	self.Producer.produce(topic, request.value, request.key, self.Partition, callback=self.Acked)
	self.Producer.flush()

	if self.ProduceError != '':
		raise KafkaException(self.ProduceError)
}

Method Acked(err As %String, msg As %String) [ Language = python ]
{
	if err is not None:
		self.ProduceError = f'Failed to deliver message: {str(err)}'
}

XData %import [ MimeType = application/python ]
{
from confluent_kafka import Producer, KafkaException
}

}

/// Use confluent-kafka-python library
Class Kafka.Adapter.Inbound Extends (Kafka.Adapter.Common, Ens.InboundAdapter)
{

/// Topic that the messages are read from.
Property Topic As %String(MAXLEN = 100);

/// Kafka consumer group ID. Within the same group, each message is only read once.
Property GroupID As %String(MAXLEN = 100) [ InitialExpression = {"IRIS-"_$NAMESPACE} ];

/// Deprecated. Use ConfigLookupTable instead
Property ReceiveSettings As %String(MAXLEN = 300) [ Deprecated ];

/// The partition to read from
Property Partition As %Integer [ InitialExpression = 0 ];

/// You can use this lookup table as a common storage for default configs for all Consumers. 
/// It is needed not to repeat all settings in each service when we read different partitions, for example. 
/// Also, to this table, you can add parameters which not defined as Business Host Settings (full list of parameters available here: 
/// https://docs.confluent.io/platform/current/installation/configuration/consumer-configs.html). 
/// Business Host settings (Servers, Credentials, GroupID, etc.) will redefine parameters from the ConfigLookupTable.
Property ConfigLookupTable As %String [ InitialExpression = "Kafka.ConsumerConfigs" ];

/// If this option is enabled, IRIS will change the message offset in Kafka only after receiving a non-failure response from the target Business Host(s). 
/// "At least once" type of guarantee if this option is enabled / "At most once" type of guarantee if this option is disabled (no garantee).
Property GuaranteeDelivery As %Boolean;

Parameter SETTINGS = "Topic:Kafka Settings,GroupID:Kafka Settings,ReceiveSettings:Kafka Settings,Partition:Kafka Settings,ConfigLookupTable:Kafka Settings,GuaranteeDelivery:Kafka Settings";

/// The Kafka Consumer
Property Consumer As %SYS.Python [ Private ];

/// Create the Kafka client here
Method OnInit() As %Status
{
	Set tSC = ..GetConfDict(..ConfigLookupTable, .config)
	Return:$$$ISERR(tSC) tSC

	Do ..OverrideByLocal(.config)
	Do:..GroupID'="" config.setdefault("group.id", ..GroupID)

	If ..GuaranteeDelivery {
		Do config.setdefault("enable.auto.commit", ##class(%SYS.Python).True())
		Do config.setdefault("enable.auto.offset.store", ##class(%SYS.Python).False())
	}

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
		raise KafkaException('No Kafka servers configured (check \'bootstrap.servers\' in ConfigLookupTable or \'Servers\' in settings of Service)')
	if self.Topic == '':
		raise KafkaException('No Kafka topic configured (check \'Topic\' in settings of Service)')

	self.Consumer = Consumer(config)
	self.Consumer.assign([TopicPartition(self.Topic, self.Partition)])
}

Method DestroyKafkaClient() [ Language = python ]
{
	self.Consumer.close()
}

Method Poll() As EnsLib.Kafka.Message [ Language = python ]
{
	msg = self.Consumer.poll(timeout=0.1)
	
	if msg is None: 
		return ''
	if msg.error():
		if msg.error().code() == KafkaError._PARTITION_EOF:
			return ''
		else:
			raise KafkaException(msg.error())
	
	if not self.GuaranteeDelivery:
		self.CommitOffset()

	input = iris.EnsLib.Kafka.Message._New()
	input.topic = msg.topic()
	input.key = msg.key().decode('utf-8')
	input.value = msg.value().decode('utf-8')

	return input
}

Method CommitOffset() [ Language = python ]
{
	self.Consumer.commit(asynchronous=False)
}

Method OnTask() As %Status
{
	Set tSC = $$$OK
	Set input = $$$NULLOREF
	
	Try {Set input = ..Poll()} Catch ex {Set tSC = ex.AsStatus()}
	Return:$$$ISERR(tSC) tSC

	If input '= $$$NULLOREF {
		Set tSC = ..BusinessHost.ProcessInput(input)
		
		If ..GuaranteeDelivery && $$$ISOK(tSC) {
			Try {Do ..CommitOffset()} Catch ex {Set tSC = ex.AsStatus()}	
		}	
	}

	Set ..BusinessHost.%WaitForNextCallInterval = 1
	
	Return tSC
}

XData %import [ MimeType = application/python ]
{
import iris
from confluent_kafka import Consumer, KafkaException, TopicPartition, KafkaError
}

}

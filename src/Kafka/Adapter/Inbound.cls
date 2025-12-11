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
/// It means repeatedly pulling the same Kafka message until the message is successfully delivered to its target.
Property AtLeastOnce As %Boolean;

Parameter SETTINGS = "Topic:Kafka Settings,GroupID:Kafka Settings,ReceiveSettings:Kafka Settings,Partition:Kafka Settings,ConfigLookupTable:Kafka Settings,AtLeastOnce:Kafka Settings";

/// The Kafka Consumer
Property Consumer As %SYS.Python [ Private ];

/// Needed for committing the offset after message processing
Property LastMessage As %SYS.Python [ Private ];

/// Create the Kafka client here
Method OnInit() As %Status
{
	Set tSC = ..GetConfDict(..ConfigLookupTable, .config)
	Return:$$$ISERR(tSC) tSC

	Do ..OverrideByLocal(.config)

	Do:..GroupID'="" config.setdefault("group.id", ..GroupID)
	Do:..AtLeastOnce config.setdefault("enable.auto.commit", ##class(%SYS.Python).False())

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
	def commit_completed(err, partitions):
		if err:
			self.Trace(f'Failed to commit offsets: {str(err)}')
		else:
			self.Trace(f'Committed partition offsets: {str(partitions)}')

	config['on_commit'] = commit_completed
	
	if config['bootstrap.servers'] == '':
		raise KafkaException('No Kafka servers configured (check \'bootstrap.servers\' in ConfigLookupTable or \'Servers\' in settings of Service)')
	if self.Topic == '':
		raise KafkaException('No Kafka topic configured (check \'Topic\' in settings of Service)')
	if config['group.id'] == '':
		raise KafkaException('No Kafka group ID configured (check \'group.id\' in ConfigLookupTable or \'GroupID\' in settings of Service)')

	self.Consumer = Consumer(config)
	self.Consumer.assign([TopicPartition(self.Topic, self.Partition)])
}

Method DestroyKafkaClient() [ Language = python ]
{
	self.Consumer.close()
}

Method ResetKafkaClient() [ Language = python ]
{
	self.Consumer.seek(TopicPartition(self.Topic, self.Partition))
}

Method Trace(message As %String)
{
	$$$TRACE(message)
}

Method Poll() As EnsLib.Kafka.Message [ Language = python ]
{
	self.LastMessage = self.Consumer.poll(timeout=1.0)
	
	if self.LastMessage is None: 
		self.Trace('No message received')
		return ''
	if self.LastMessage.error():
		if self.LastMessage.error().code() == KafkaError._PARTITION_EOF:
			self.Trace('End of partition reached')
			return ''
		else:
			raise KafkaException(self.LastMessage.error())

	input = iris.EnsLib.Kafka.Message._New()
	input.topic = self.LastMessage.topic()
	input.key = self.LastMessage.key().decode('utf-8')
	input.value = self.LastMessage.value().decode('utf-8')
	
	self.Trace(f'Received message: {input.value}')

	return input
}

Method CommitOffset() [ Language = python ]
{
	self.Consumer.commit(message=self.LastMessage, asynchronous=False)
	self.Trace(f'Message offset {self.LastMessage.offset()} commit manually')
}

Method OnTask() As %Status
{
	Set tSC = $$$OK
	
	Try {
		Set input = ..Poll()
		If input '= $$$NULLOREF {
			Set tSC = ..BusinessHost.ProcessInput(input)
			If ..AtLeastOnce {
				If $$$ISOK(tSC) {
					Do ..CommitOffset()
				} Else {
					Do ..ResetKafkaClient()
				}
			}
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
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

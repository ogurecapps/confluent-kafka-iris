/// Used confluent-kafka-python library
Class Kafka.Adapter.Inbound Extends (Kafka.Adapter.Common, Ens.InboundAdapter)
{

/// Topic that the messages are read from
Property Topic As %String(MAXLEN = 100);

/// Kafka consumer group ID. Within the same group, each message is only read once
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

/// The maximum number of messages to process in one call interval
Property BatchSize As %Integer [ InitialExpression = 100 ];

Parameter SETTINGS = "Topic:Kafka Settings,GroupID:Kafka Settings,ReceiveSettings:Kafka Settings,Partition:Kafka Settings,ConfigLookupTable:Kafka Settings,AtLeastOnce:Kafka Settings,BatchSize:Kafka Settings";

/// The Kafka Consumer
Property Consumer As %SYS.Python [ Private ];

/// Batch of messages received from the last consume() call
Property MessageBatch As %SYS.Python [ Private ];

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

/// After an error occurs, the read position in the Kafka client must be reset to the last successfully read position
Method ResetKafkaClient() [ Language = python ]
{
	tp = TopicPartition(self.Topic, self.Partition)
	committed = self.Consumer.committed([tp], timeout=1.0)
	if committed and committed[0].offset >= 0:
		self.Consumer.seek(committed[0])
		self.Trace(f'Reset to last committed offset {committed[0].offset}')
}

Method Trace(message As %String)
{
	$$$TRACE(message)
}

/// Sets a received message batch to the class property and returns its size
Method Consume() As %Integer [ Language = python ]
{
	self.MessageBatch = self.Consumer.consume(num_messages=self.BatchSize, timeout=1.0)
	return len(self.MessageBatch) if self.MessageBatch is not None else 0
}

/// Returns EnsLib.Kafka.Message for the message at index, or empty string if it's an error/EOF
Method BuildInput(index As %Integer) As EnsLib.Kafka.Message [ Language = python ]
{
    msg = self.MessageBatch[index]

    if msg.error():
        if msg.error().code() == KafkaError._PARTITION_EOF:
            self.Trace('End of partition reached')
            return ''
        else:
            raise KafkaException(msg.error())

    input = iris.EnsLib.Kafka.Message._New()
    input.topic = msg.topic()
    input.key = msg.key().decode('utf-8')
    input.value = msg.value().decode('utf-8')

    self.Trace(f'Processing message: {input.value}')
    return input
}

Method CommitOffset(index As %Integer) [ Language = python ]
{
	msg = self.MessageBatch[index]
	self.Consumer.commit(message=msg, asynchronous=False)
	self.Trace(f'Message offset {msg.offset()} commit manually')
}

Method OnTask() As %Status
{
	Set tSC = $$$OK
	
	Try {
		Set total = ..Consume()
		$$$TRACE($$$FormatText("Received batch of %1 messages", total))
		
		For i=0:1:(total-1) {
            Set input = ..BuildInput(i) Quit:input=""
				
			Set tSC = ..BusinessHost.ProcessInput(input)
			If ..AtLeastOnce {
				If $$$ISOK(tSC) {
					Do ..CommitOffset(i)
				} Else {
					Do ..ResetKafkaClient()
					Quit
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

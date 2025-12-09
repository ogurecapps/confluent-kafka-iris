/// Business Operation to send a Kafka message
Class Kafka.Operation.Producer Extends Ens.BusinessOperation
{

Parameter ADAPTER = "Kafka.Adapter.Outbound";

Property Adapter As Kafka.Adapter.Outbound;

Parameter INVOCATION = "Queue";

/// OnMessage returns a bad status when the adapter fails to send the outgoing Kafka message
Method OnMessage(pRequest As EnsLib.Kafka.Message, Output pResponse As %Library.Persistent) As %Status
{
	Return ..Adapter.Produce(pRequest)
}

}

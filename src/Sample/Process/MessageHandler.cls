Class Sample.Process.MessageHandler Extends Ens.BusinessProcess [ ClassType = persistent ]
{

Property ThrowError As %Boolean;

Property ProcessingTimeSec As %Integer [ InitialExpression = 5 ];

Parameter SETTINGS = "ThrowError:Basic,ProcessingTimeSec:Basic";

/// Handle a 'Request'
Method OnRequest(request As EnsLib.Kafka.Message, Output response As Ens.Response) As %Status
{
	Set response = ##class(Ens.Response).%New()
	Hang ..ProcessingTimeSec
	Return $SELECT(..ThrowError:$$$ERROR($$$GeneralError,"Something went wrong"),1:$$$OK)
}

Storage Default
{
<Data name="MessageHandlerDefaultData">
<Subscript>"MessageHandler"</Subscript>
<Value name="1">
<Value>ThrowError</Value>
</Value>
<Value name="2">
<Value>ProcessingTimeSec</Value>
</Value>
</Data>
<DefaultData>MessageHandlerDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}

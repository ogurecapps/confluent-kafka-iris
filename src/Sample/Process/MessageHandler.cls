Class Sample.Process.MessageHandler Extends Ens.BusinessProcess [ ClassType = persistent ]
{

Property ThrowError As %Boolean;

Parameter SETTINGS = "ThrowError:Basic";

/// Handle a 'Request'
Method OnRequest(request As EnsLib.Kafka.Message, Output response As Ens.Response) As %Status
{
	Return $SELECT(..ThrowError:$$$ERROR($$$GeneralError,"Something went wrong"),1:$$$OK)
}

Storage Default
{
<Data name="MessageHandlerDefaultData">
<Subscript>"MessageHandler"</Subscript>
<Value name="1">
<Value>ThrowError</Value>
</Value>
</Data>
<DefaultData>MessageHandlerDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}

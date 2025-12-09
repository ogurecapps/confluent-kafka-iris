Class Sample.Process.MessageGenerator Extends Ens.BusinessProcess [ ClassType = persistent ]
{

/// Handle a 'Request'
Method OnRequest(request As Ens.Request, Output response As Ens.Response) As %Status
{
	Set tSC = $$$OK

    For i=0:1:1 {
        Set msg = ##class(EnsLib.Kafka.Message).%New()
        Set msg.value = {"random": ($RANDOM(1000000)), "partition": (i)}.%ToJSON()
        Set tSC = ..SendRequestAsync($$$FormatText("Kafka.Operation.Producer.Part%1", i), msg, 0)
        Quit:$$$ISERR(tSC)    
    }

    Return tSC
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}

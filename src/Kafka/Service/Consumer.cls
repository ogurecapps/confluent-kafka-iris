Class Kafka.Service.Consumer Extends Ens.BusinessService
{

Property TargetConfigNames As Ens.DataType.ConfigName;

Property Adapter As Kafka.Adapter.Inbound;

Parameter ADAPTER = "Kafka.Adapter.Inbound";

Parameter SETTINGS = "TargetConfigNames:Basic:selector?multiSelect=1&context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

Method OnProcessInput(pInput As EnsLib.Kafka.Message, Output pOutput As Ens.Response) As %Status
{
	Set tSC = $$$OK
	Set targets = $LISTFROMSTRING(..TargetConfigNames)

	For i=1:1:$LISTLENGTH(targets) {
		Set target = $LISTGET(targets, i)
		If ..Adapter.GuaranteeDelivery {
			Set tSC = ..SendRequestSync(target, pInput, .pOutput) // We have no option to get a response when we use async sending in the Business Service
		} Else {
			Set tSC = ..SendRequestAsync(target, pInput)
		}
		Quit:$$$ISERR(tSC)
	}

	Return tSC
}

}

/// Common settings and utilities for adapters
Class Kafka.Adapter.Common Extends EnsLib.Kafka.Common
{

/// Overrides common settings from the Lookup Table with local ones
Method OverrideByLocal(ByRef config As %SYS.Python)
{
	If ..Credentials '= "" {
		Do config.setdefault("sasl.username", ##class(Ens.Config.Credentials).GetValue(..Credentials, "Username"))
		Do config.setdefault("sasl.password", ##class(Ens.Config.Credentials).GetValue(..Credentials, "Password"))
	}

	Do:..Servers'="" config.setdefault("bootstrap.servers", ..Servers)
	Do:..SecurityProtocol'="" config.setdefault("security.protocol", ..SecurityProtocol)
	Do:..SASLMechanism'="" config.setdefault("sasl.mechanism", ..SASLMechanism)
    Do:..TrustStoreLocation'="" config.setdefault("ssl.truststore.location", ..TrustStoreLocation)
    Do:..TrustStoreCredentials'="" config.setdefault("ssl.truststore.password", ##class(Ens.Config.Credentials).GetValue(..TrustStoreCredentials, "Password"))
    Do:..KeyStoreLocation'="" config.setdefault("ssl.keystore.location", ..KeyStoreLocation)
    Do:..KeyStoreCredentials'="" config.setdefault("ssl.keystore.password", ##class(Ens.Config.Credentials).GetValue(..KeyStoreCredentials, "Password"))
    Do:..KeyCredentials'="" config.setdefault("ssl.key.password", ##class(Ens.Config.Credentials).GetValue(..KeyCredentials, "Password"))
}

ClassMethod GetConfDict(tableName As %String, Output confDict As %SYS.Python) As %Status
{
    Set confDict = ##class(%SYS.Python).Builtins().dict()

    Set stmt = ##class(%SQL.Statement).%New()
    Set tSC = stmt.%Prepare("select KeyName, DataValue from Ens_Util.LookupTable where TableName = ?")
    Return:$$$ISERR(tSC) tSC

    Set rset = stmt.%Execute(tableName)
    Return:rset.%SQLCODE'=0 $$$ERROR($$$GeneralError, $$$FormatText("Execute failed. SQLCODE = %1: %2", rset.%SQLCODE, rset.%Message))

    While rset.%Next() {
        Do confDict.setdefault(rset.%Get("KeyName"), ..GetPythonValue(rset.%Get("DataValue")))
    }
    Return:rset.%SQLCODE<0 $$$ERROR($$$GeneralError, $$$FormatText("Next failed. SQLCODE = %1: %2", rset.%SQLCODE, rset.%Message))
    
    Return $$$OK
}

ClassMethod GetPythonValue(dataValue As %String) As %SYS.Python
{
    Return:dataValue=+dataValue +dataValue
    Return:$ZCONVERT(dataValue,"l")="true" ##class(%SYS.Python).True()
    Return:$ZCONVERT(dataValue,"l")="false" ##class(%SYS.Python).False()
    Return:$ZCONVERT(dataValue,"l")="none" ##class(%SYS.Python).None()
    
    Return dataValue
}

}

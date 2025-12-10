Class Production.Main Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="Production.Main" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description></Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Setting Target="Adapter" Name="ShutdownTimeout">30</Setting>
  <Item Name="Kafka.Service.Consumer.Part1" Category="" ClassName="Kafka.Service.Consumer" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="Partition">1</Setting>
    <Setting Target="Host" Name="TargetConfigNames">Sample.Process.MessageHandler</Setting>
    <Setting Target="Adapter" Name="CallInterval">5</Setting>
    <Setting Target="Adapter" Name="Servers">kafka:9092</Setting>
    <Setting Target="Adapter" Name="Topic">test</Setting>
  </Item>
  <Item Name="Kafka.Operation.Producer.Part0" Category="" ClassName="Kafka.Operation.Producer" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="Partition">0</Setting>
    <Setting Target="Adapter" Name="Topic">test</Setting>
    <Setting Target="Adapter" Name="Servers">kafka:9092</Setting>
  </Item>
  <Item Name="Kafka.Operation.Producer.Part1" Category="" ClassName="Kafka.Operation.Producer" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="Partition">1</Setting>
    <Setting Target="Adapter" Name="Topic">test</Setting>
    <Setting Target="Adapter" Name="Servers">kafka:9092</Setting>
  </Item>
  <Item Name="Sample.Process.MessageHandler" Category="" ClassName="Sample.Process.MessageHandler" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Sample.Process.MessageGenerator" Category="" ClassName="Sample.Process.MessageGenerator" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Sample.Service.MessageGenerator" Category="" ClassName="Sample.Service.IntervalCall" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="TargetConfigNames">Sample.Process.MessageGenerator</Setting>
    <Setting Target="Adapter" Name="CallInterval">3600</Setting>
  </Item>
</Production>
}

}

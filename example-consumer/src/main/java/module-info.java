import co.elastic.connectors.api.Connector;

module example.consumer {
    requires org.jruby.complete;
    requires transitive hello.world.connector;
    uses Connector;
}

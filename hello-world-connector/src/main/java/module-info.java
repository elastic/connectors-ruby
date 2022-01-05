import co.elastic.connectors.api.Connector;
import co.elastic.connectors.hello.world.HelloWorld;

open module hello.world.connector {
    requires java.desktop;
    requires org.jruby.complete;
    requires transitive connectors.api;
    uses Connector;
    provides Connector with HelloWorld;
}
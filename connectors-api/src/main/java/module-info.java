open module connectors.api {
    uses co.elastic.connectors.api.Connector;
    requires java.desktop;
    requires org.jruby.complete;
    exports co.elastic.connectors.api;
}
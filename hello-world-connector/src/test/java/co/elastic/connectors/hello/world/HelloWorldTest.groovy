package co.elastic.connectors.hello.world

import spock.lang.Specification

class HelloWorldTest extends Specification {

    def "test that the class works"(){
        setup:
        HelloWorld helloWorld = new HelloWorld()

        expect:
        helloWorld.fetch_documents().equals([
                "title" : "Traditional Test",
                "body" : "Hello, world"
        ])
    }

    def "test stack traces"(){
        setup:
        HelloWorld helloWorld = new HelloWorld()

        when:
        helloWorld.do_risky_thing()

        then:
        Exception e = thrown()
        e.printStackTrace()
    }
}

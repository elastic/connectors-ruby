/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License;
 * you may not use this file except in compliance with the Elastic License.
 */

package co.elastic.connectors.hello.world

import co.elastic.connectors.api.Connector
import spock.lang.Specification

class HelloWorldTest extends Specification {

    def "test that the class works"(){
        setup:
        HelloWorld helloWorld = new HelloWorld()

        expect:
        helloWorld.fetchDocuments()[0].equals([
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

    def "test inheritance"(){
        setup:
        HelloWorld helloWorld = new HelloWorld()

        expect:
        helloWorld instanceof Connector
        ((Connector) helloWorld).fetchDocuments()
    }
}

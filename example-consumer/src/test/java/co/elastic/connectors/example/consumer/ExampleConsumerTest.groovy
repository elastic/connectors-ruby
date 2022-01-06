/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License;
 * you may not use this file except in compliance with the Elastic License.
 */

package co.elastic.connectors.example.consumer

import org.jruby.Ruby
import org.jruby.exceptions.LoadError
import spock.lang.Specification

class ExampleConsumerTest extends Specification {

    def "test consumer"(){
        setup:
        def consumer = new ExampleConsumer()

        when:
        consumer.doThing()

        then:
        noExceptionThrown()
    }

    def "test global runtime can access transitive gems"(){
        setup:
        Ruby runtime = Ruby.getGlobalRuntime()

        when: "awesome print"
        runtime.executeScript("require 'awesome_print'", 'foo.rb') // transitive from hello-world-connector

        then:
        1==1

        when: "active_support"
        runtime.executeScript("require 'active_support'", 'foo.rb') // not transitively included

        then:
        LoadError e = thrown(LoadError)
        e.message.contains("no such file to load -- active_support")
    }
}

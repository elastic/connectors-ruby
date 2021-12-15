require 'java'
require 'awesome_print'
java_import 'co.elastic.connectors.api.Connector'
java_import 'java.util.List'

java_package 'co.elastic.connectors.hello.world'
class HelloWorld
  java_implements 'co.elastic.connectors.api.Connector'

  java_signature 'List fetchDocuments()'
  def fetch_Documents
    documents = [
      {
        'title' => 'Traditional Test',
        'body' => 'Hello, world'
      }
    ]
    puts 'these are the documents:'
    ap documents
    documents
  end

  def do_risky_thing
    do_risky_thing_helper
  end

  def do_risky_thing_helper
    throw_exception
  end

  def throw_exception
    raise "Oh dear, an error"
  end
end
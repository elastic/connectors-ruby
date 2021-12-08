require 'java'
java_package 'co.elastic.connectors.hello.world'
class HelloWorld
  def fetch_documents
    {
      'title' => 'Traditional Test',
      'body' => 'Hello, world'
    }
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
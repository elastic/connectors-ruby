# frozen_string_literal: true
require 'set'
require 'nokogiri'

module ExtractionUtils
  # A list of tags tags we want to remove before extracting content
  NON_CONTENT_TAGS = Set.new(%w[
    comment
    object
    script
    style
    svg
    video
  ]).freeze

  # Tags, that generate a word/line break when rendered
  BREAK_ELEMENTS = Set.new(%w[
    br
    hr
  ]).freeze

  # The character used to signal that a string has been truncated
  OMISSION = '…'

  #-------------------------------------------------------------------------------------------------
  # Expects a Nokogiri HTML node, returns textual content from the node and all of its children
  def self.node_descendant_text(node)
    return '' unless node&.present?

    unless node.respond_to?(:children) && node.respond_to?(:name) && node.respond_to?(:text?)
      raise ArgumentError, "Expecting something node-like but got a #{node.class}"
    end

    to_process_stack = [node]
    text = []

    loop do
      # Get the next node to process
      node = to_process_stack.pop
      break unless node

      # Base cases where we append content to the text buffer
      if node.kind_of?(String)
        text << node unless node == ' ' && text.last == ' '
        next
      end

      # Remove tags that do not contain any text (and which sometimes are treated as CDATA, generating garbage text in jruby)
      next if NON_CONTENT_TAGS.include?(node.name)

      # Tags, that need to be replaced by spaces according to the standards
      if replace_with_whitespace?(node)
        text << ' ' unless text.last == ' '
        next
      end

      # Extract the text from all text nodes
      if node.text?
        content = node.content
        text << content.squish if content
        next
      end

      # Add spaces before all tags
      to_process_stack << ' '

      # Recursion by adding the node's children to the stack and looping
      node.children.reverse_each { |child| to_process_stack << child }

      # Add spaces after all tags
      to_process_stack << ' '
    end

    # Remove any duplicate spaces and return the content
    text.join.squish!
  end

  #-------------------------------------------------------------------------------------------------
  # Returns true, if the node should be replaced with a space when extracting text from a document
  def self.replace_with_whitespace?(node)
    BREAK_ELEMENTS.include?(node.name)
  end

  #-------------------------------------------------------------------------------------------------
  # Limits the size of a given string value down to a given limit (in bytes)
  # This is heavily inspired by https://github.com/rails/rails/pull/27319/files
  def self.limit_bytesize(string, limit)
    return string if string.nil? || string.bytesize <= limit
    real_limit = limit - OMISSION.bytesize
    (+'').tap do |cut|
      string.scan(/\X/) do |grapheme|
        if cut.bytesize + grapheme.bytesize <= real_limit
          cut << grapheme
        else
          cut << OMISSION
          break
        end
      end
    end
  end
end
# frozen_string_literal: true

require_relative "typed_struct/version"
require_relative "typed_struct/type_checking"
require "rbs"

class TypedStruct < Struct
  include TypeChecking

  class << self
    def new(**properties)
      super(*properties.keys, keyword_init: true).tap do |klass|
        klass.class.instance_eval do
          include TypeChecking
          attr_reader :options
        end

        klass.instance_eval do
          @options = { types: properties }
          properties.each_key do |k|
            define_method :"#{k}=" do |val|
              prop = properties[k]
              if val_is_type? val, prop
                raise "Unexpected type #{val.class} for #{k.inspect} (expected #{prop})"
              end
              # it seems that structs behave in such a way that you can't call super here, but it
              # will still set the value anyway
            end
          end
        end
      end
    end
  end

  def initialize(**attrs)
    opts = self.class.options
    opts[:types].each do |prop, expected_type|
      passed_value = attrs[prop]
      next if val_is_type? passed_value, expected_type

      raise "Unexpected type #{passed_value.class} for #{prop.inspect} (expected #{expected_type})"
    end

    super
  end
end

def Rbs(type_str)
  RBS::Parser.parse_type(type_str)
end

# frozen_string_literal: true

require_relative "typed_struct/version"
require_relative "typed_struct/type_checking"
require "rbs"

def Rbs(type_str)
  RBS::Parser.parse_type(type_str)
end

class TypedStruct < Struct
  include TypeChecking

  OVERRIDING_NATIVE_METHOD_MSG =
    "*** WARNING *** property %s overrides a native method in #{name}. Consider using something else (called from %s)".freeze

  # any methods which are able to be overridden
  alias_method :__class__, :class

  Options = nil

  class << self
    def new(opts = Options.new, **properties)
      properties.each_key do |prop|
        if method_defined?(prop)
          $stdout.puts OVERRIDING_NATIVE_METHOD_MSG % [prop.inspect, caller(3).first]
        end
      end

      super(*properties.keys, keyword_init: true).tap do |klass|
        klass.class.instance_eval do
          include TypeChecking
          attr_reader :options
        end

        klass.instance_eval do
          @options = { types: properties, options: opts }

          define_method :[]= do |key, val|
            prop = properties[key]
            unless val_is_type? val, prop
              raise "Unexpected type #{val.class} for #{key.inspect} (expected #{prop})"
            end

            super key, val
          end

          properties.each_key do |k|
            define_method :"#{k}=" do |val|
              self[k] = val
            end
          end
        end
      end
    end
  end

  def initialize(**attrs)
    opts = self.__class__.options
    vals = opts[:types].to_h do |prop, expected_type|
      value = attrs.fetch(prop, opts[:options][:default])
      unless val_is_type? value, expected_type
        raise "Unexpected type #{value.class} for #{prop.inspect} (expected #{expected_type})"
      end
      [prop, value]
    end

    super **vals
  end

  Options = TypedStruct.new({ default: nil }, default: Rbs("untyped"))
end

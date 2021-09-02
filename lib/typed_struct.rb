# frozen_string_literal: true

require_relative "typed_struct/version"
require_relative "typed_struct/type_checking"
require "rbs"

class TypedStruct < Struct
  include TypeChecking

  OVERRIDING_NATIVE_METHOD_MSG =
    "*** WARNING *** property %s overrides a native method in #{name}. Consider using something else (called from %s)".freeze

  # any methods which are able to be overridden
  alias_method :__class__, :class

  class << self
    def new(**properties)
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
          @options = { types: properties }

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

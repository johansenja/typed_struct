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

  class << self
    @@default_keyword_init = nil

    def default_keyword_init
      @@default_keyword_init
    end

    def default_keyword_init=(default)
      @@default_keyword_init = default
    end

    def new(opts = Options.new, **properties)
      if opts[:keyword_init].nil?
        opts[:keyword_init] = if RUBY_VERSION < "3.2"
          default_keyword_init || false
        else
          default_keyword_init
        end
      end

      properties.each_key do |prop|
        if method_defined?(prop)
          warn OVERRIDING_NATIVE_METHOD_MSG % [prop.inspect, caller(3).first]
        end
      end

      super(opts[:class_name], *properties.keys, keyword_init: opts[:keyword_init]).tap do |klass|
        klass.class.instance_eval do
          include TypeChecking
          attr_reader :options
        end

        klass.instance_eval do
          @options = { types: properties, options: opts }

          define_method :[]= do |key, val|
            if key.is_a?(Integer)
              key = if key.negative?
                offset = self.members.size + key
                if offset.negative?
                  raise IndexError, "offset #{key} too small for struct(size:#{self.members.size})"
                end
                self.members[offset]
              elsif key >= self.members.size
                raise IndexError, "offset #{key} too large for struct(size:#{self.members.size})"
              else
                self.members[key]
              end
            end
            unless properties.key?(key)
              raise NameError, "no member '#{key}' in struct"
            end
            prop = properties[key]
            unless val_is_type? val, prop
              raise TypeError, "unexpected type #{val.class} for #{key.inspect} (expected #{prop})"
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

  def initialize(*positional_attrs, **attrs)
    opts = self.__class__.options
    if opts[:options][:keyword_init] == true && !positional_attrs.empty?
      raise ArgumentError, "wrong number of arguments (given #{positional_attrs.size}, expected 0)"
    elsif (opts[:options][:keyword_init] == false && !attrs.empty?) ||
        (opts[:options][:keyword_init] != true && !positional_attrs.empty?)
      positional_attrs << attrs unless attrs.empty?
      attrs = positional_attrs.zip(self.members).to_h(&:reverse)
    end

    if !positional_attrs.empty? && attrs.size > self.members.size
      raise ArgumentError, "struct size differs"
    elsif !(attrs.keys - self.members).empty?
      raise ArgumentError, "unknown keywords: #{(attrs.keys - self.members).join(', ')}"
    end

    vals = opts[:types].to_h do |prop, expected_type|
      value = attrs.fetch(prop, opts[:options][:default])
      unless val_is_type? value, expected_type
        raise TypeError, "unexpected type #{value.class} for #{prop.inspect} (expected #{expected_type})"
      end
      [prop, value]
    end

    if opts[:options][:keyword_init]
      super **vals
    else
      super *vals.values
    end
  end

  Options = TypedStruct.new(
    { default: nil, keyword_init: true },
    default: Rbs("untyped"),
    keyword_init: Rbs("bool?"),
    class_name: Rbs("String? | Symbol?")
  )
end

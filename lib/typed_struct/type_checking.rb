class TypedStruct < Struct
  module TypeChecking
    private

    def val_is_type?(val, expected_type)
      return val_is_rbs_type? val, expected_type if expected_type.class.to_s.start_with? "RBS::Types"

      expected_type === val
    end

    def get_class(type_name)
      (@const_cache ||= {})[type_name] ||= begin
          Object.const_get(type_name.to_s)
        rescue NameError
          nil
        end
    end

    def each_sample(array, &block)
      if block
        if sample_size && array.size > sample_size
          if sample_size > 0
            size = array.size
            sample_size.times do
              yield array[rand(size)]
            end
          end
        else
          array.each(&block)
        end
      else
        enum_for :each_sample, array
      end
    end

    def val_is_rbs_type?(val, type)
      case type
      when RBS::Types::Bases::Any
        true
      when RBS::Types::Bases::Bool
        val.is_a?(TrueClass) || val.is_a?(FalseClass)
      when RBS::Types::Bases::Top
        true
      when RBS::Types::Bases::Bottom
        false
      when RBS::Types::Bases::Void
        true
      when RBS::Types::Bases::Self
        val_is_type? val, self.class
      when RBS::Types::Bases::Nil
        val_is_type? val, NilClass
      when RBS::Types::Bases::Class
        val_is_type? val, Class
      when RBS::Types::Bases::Instance
        val_is_type? val, Object
      when RBS::Types::ClassInstance
        klass = get_class(type.name) or return false
        case
        when klass == ::Array
          val_is_type?(val, klass) && each_sample(val).all? { |v| val_is_type?(v, type.args[0]) }
        when klass == ::Hash
          val_is_type?(val, klass) && each_sample(val.keys).all? do |key|
            val_is_type?(key, type.args[0]) && val_is_type?(val[key], type.args[1])
          end
        when klass == ::Range
          val_is_type?(val, klass) && val_is_type?(val.begin, type.args[0]) && val_is_type?(val.end, type.args[0])
        when klass == ::Enumerator
          if val_is_type? val, klass
            case val.size
            when Float::INFINITY
              values = []
              ret = self
              val.lazy.take(10).each do |*args|
                values << args
                nil
              end
            else
              values = []
              ret = val.each do |*args|
                values << args
                nil
              end
            end

            each_sample(values).all? do |v|
              if v.size == 1
                # Only one block argument.
                val_is_type?(v[0], type.args[0]) || value(v, type.args[0])
              else
                val_is_type?(v, type.args[0])
              end
            end &&
              if ret.equal?(self)
                type.args[1].is_a?(Types::Bases::Bottom)
              else
                val_is_type?(ret, type.args[1])
              end
          end
        else
          val_is_type? val, klass
        end
      when RBS::Types::ClassSingleton
        klass = get_class(type.name) or return false
        singleton_class = begin
            klass.singleton_class
          rescue TypeError
            return false
          end
        val.is_a?(singleton_class)
      when RBS::Types::Interface
        methods = Set.new(val.methods)
        if (definition = builder.build_interface(type.name))
          definition.methods.each_key.all? do |method_name|
            methods.member?(method_name)
          end
        end
      when RBS::Types::Variable
        true
      when RBS::Types::Literal
        val == type.literal
      when RBS::Types::Union
        type.types.any? { |type| val_is_type?(val, type) }
      when RBS::Types::Intersection
        type.types.all? { |type| val_is_type?(val, type) }
      when RBS::Types::Optional
        val_is_type?(val, NilClass) || val_is_type?(val, type.type)
      when RBS::Types::Alias
        val_is_type? val, builder.expand_alias(type.name)
      when RBS::Types::Tuple
        val_is_type?(val, Array) &&
          type.types.map.with_index { |ty, index| val_is_type?(val[index], ty) }.all?
      when RBS::Types::Record
        val_is_type?(val, Hash) &&
          type.fields.map { |key, type| val_is_type?(val[key], type) }.all?
      when RBS::Types::Proc
        val_is_type? val, Proc
      else
        false
      end
    end

    def builder
      @builder ||= RBS::DefinitionBuilder.new(
        env: RBS::Environment.from_loader(RBS::EnvironmentLoader.new).resolve_type_names,
      )
    end

    def sample_size
      100
    end
  end
end

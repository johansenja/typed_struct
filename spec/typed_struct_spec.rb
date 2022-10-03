# frozen_string_literal: true

RSpec.describe TypedStruct do
  before do
    expect(TypedStruct.class_variables).to contain_exactly :@@default_keyword_init
    TypedStruct.default_keyword_init = nil
  end

  it "helps avoid primitive obsession" do
    Price = TypedStruct.new(price: Rational) do
      %i[- + / *].each do |op|
        define_method(op) { |rhs| __class__[price.public_send(op, rhs.price)] }
      end
    end
    UserId = TypedStruct.new(user_id: Integer)

    price, user_id = 2.5r, 123456
    expect(5r).to eql price + price
    expect(5).to eq price + price
    expect { price + user_id }.not_to raise_error

    price, user_id = Price[2.5r], UserId[123456]
    expect(Price[5r]).to eql price + price
    expect { Price[5] }.to raise_error TypeError
    expect { price + user_id }.to raise_error NoMethodError
  end

  it "ensures type safety" do
    x = TypedStruct.new({ keyword_init: true }, int: Integer)
    y = x.new(int: 5)
    expect { x[int: "abc"] }.to raise_error TypeError
    expect { y[:int] = "abc" }.to raise_error TypeError
    expect { y.int = "abc" }.to raise_error TypeError
  end

  it "has default_keyword_init option" do
    attrs = RUBY_VERSION < "3.2" ?  {int: {int: 5}} : {int: 5}

    TypedStruct.default_keyword_init = nil
    expect(TypedStruct.default_keyword_init).to be nil
    x = Struct.new(:int)
    y = TypedStruct.new(int: Rbs("untyped"))
    expect(x.new(int: 5)).to have_attributes attrs
    expect(y.new(int: 5)).to have_attributes attrs

    TypedStruct.default_keyword_init = true
    expect(TypedStruct.default_keyword_init).to be true
    x = Struct.new(:int, keyword_init: true)
    y = TypedStruct.new(int: Rbs("untyped"))
    expect(x.new(int: 5)).to have_attributes int: 5
    expect(y.new(int: 5)).to have_attributes int: 5

    TypedStruct.default_keyword_init = false
    expect(TypedStruct.default_keyword_init).to be false
    x = Struct.new(:int, keyword_init: false)
    y = TypedStruct.new(int: Rbs("untyped"))
    expect(x.new(int: 5)).to have_attributes int: {int: 5}
    expect(y.new(int: 5)).to have_attributes int: {int: 5}
  end

  it "has an options attribute" do
    x = TypedStruct.new(int: Integer, str: String)
    expect(x.instance_variables).to contain_exactly :@options
    options = RUBY_VERSION < "3.2" ? TypedStruct::Options.new(keyword_init: false) : TypedStruct::Options.new
    expect(x.options).to eq types: {int: Integer, str: String}, options: options
  end

  it "has a version number" do
    expect(TypedStruct::VERSION).not_to be_nil
  end

  context "when comparing Struct behaviour" do
    it "accepts either positional or keyword arguments" do
      x = Struct.new(:int)
      y = TypedStruct.new(int: Rbs("untyped"))
      attrs = RUBY_VERSION < "3.2" ?  {int: {int: 5}} : {int: 5}
      expect(x.new(5)).to have_attributes int: 5
      expect(y.new(5)).to have_attributes int: 5
      expect(x.new(int: 5)).to have_attributes attrs
      expect(y.new(int: 5)).to have_attributes attrs
      x = Struct.new(:int, keyword_init: true)
      y = TypedStruct.new({ keyword_init: true }, int: Rbs("untyped"))
      expect(x.new(int: 5)).to have_attributes int: 5
      expect(y.new(int: 5)).to have_attributes int: 5
    end

    it "has identical error messages for bounds checks" do
      x = Struct.new(:int, keyword_init: true).new(int: 5)
      expect { x[-2] = 6 }.to raise_error IndexError, "offset -2 too small for struct(size:1)"
      expect { x[1] = 6 }.to raise_error IndexError, "offset 1 too large for struct(size:1)"
      expect { x[0] = 6 }.not_to raise_error
      expect { x[-1] = 6 }.not_to raise_error
      y = TypedStruct.new({ keyword_init: true }, int: Integer).new(int: 5)
      expect { y[-2] = 6 }.to raise_error IndexError, "offset -2 too small for struct(size:1)"
      expect { y[1] = 6 }.to raise_error IndexError, "offset 1 too large for struct(size:1)"
      expect { y[0] = 6 }.not_to raise_error
      expect { y[-1] = 6 }.not_to raise_error
    end

    it "has identical error messages for presence checks" do
      x = Struct.new(:int, keyword_init: true)
      y = TypedStruct.new({ keyword_init: true }, int: Integer)
      expect { x.new(5) }.to raise_error ArgumentError, "wrong number of arguments (given 1, expected 0)"
      expect { y.new(5) }.to raise_error ArgumentError, "wrong number of arguments (given 1, expected 0)"
      expect { x.new(str: 5, abc: "xyz") }.to raise_error ArgumentError, "unknown keywords: str, abc"
      expect { y.new(str: 5, abc: "xyz") }.to raise_error ArgumentError, "unknown keywords: str, abc"
      a = x.new(int: 5)
      b = y.new(int: 5)
      expect { a.str = 5 }.to raise_error NoMethodError, "undefined method `str=' for #<struct int=5>"
      expect { b.str = 5 }.to raise_error NoMethodError, "undefined method `str=' for #<struct int=5>"
      expect { a[:str] = 5 }.to raise_error NameError, "no member 'str' in struct"
      expect { b[:str] = 5 }.to raise_error NameError, "no member 'str' in struct"
      x = Struct.new(:int)
      y = TypedStruct.new(int: Integer)
      expect { x.new(5, 6) }.to raise_error ArgumentError, "struct size differs"
      expect { y.new(5, 6) }.to raise_error ArgumentError, "struct size differs"
    end

    it "supports the same methods" do
      a = Struct.new(:str, :int)
      b = TypedStruct.new(str: String, int: Integer)
      expect(a.public_methods).to contain_exactly *b.public_methods.grep_v(:default_keyword_init).grep_v(:default_keyword_init=)
      expect(a.public_instance_methods).to contain_exactly *b.public_instance_methods.grep_v(:__class__)
      expect(a.public_instance_methods(false)).to contain_exactly *b.new("abc", 5).public_methods(false).grep_v(:[]=)
    end

    it "supports the same options" do
      Struct.new("Foo", :a, :b, keyword_init: true) do
        def c
          a + b
        end
      end
      TypedStruct.new({ class_name: "Foo", keyword_init: true }, a: Rbs("untyped"), b: Rbs("untyped")) do
        def c
          a + b
        end
      end
      expect { TypedStruct::Bar }.to raise_error NameError
      expect { TypedStruct::Foo }.not_to raise_error
      expect(Struct::Foo.keyword_init?).to eq TypedStruct::Foo.keyword_init? unless RUBY_VERSION < "3.1"
      expect(Struct::Foo.new(a: 1, b: 2).c).to eq TypedStruct::Foo.new(a: 1, b: 2).c
    end

    describe "class methods" do
      let!(:struct) { Struct.new(:a, :b, :c) }
      let!(:typed_struct) { TypedStruct.new(a: Rbs("untyped"), b: Rbs("untyped"), c: Rbs("untyped")) }

      before do |example|
        testable_methods = Struct.new(:test).methods(false)
        unless (example.description.split(?/).map(&:to_sym) - testable_methods).empty?
          raise "unrecognised test: #{example.description}\navailable to test: #{testable_methods.join(?/)}"
        end
      end

      it "inspect" do
        x = Struct.new(:a, keyword_init: true)
        y = TypedStruct.new({ keyword_init: true }, a: Rbs("untyped"))
        expect(x.inspect).to end_with "(keyword_init: true)"
        expect(y.inspect).to end_with "(keyword_init: true)"
        a = Struct.new(:a, keyword_init: false)
        b = TypedStruct.new({ keyword_init: false }, a: Rbs("untyped"))
        c = Struct.new(:a)
        d = TypedStruct.new(a: Rbs("untyped"))
        expect([a, b, c, d].map { |x| x.inspect[-1] }.join).to eq ?> * 4
      end

      it "members" do
        expect(struct.members).to eq typed_struct.members
      end

      it "keyword_init?", skip: RUBY_VERSION < "3.1" do
        x = Struct.new(:a, keyword_init: true)
        y = TypedStruct.new({ keyword_init: true }, a: Rbs("untyped"))
        expect(x.keyword_init?).to eq y.keyword_init?
      end

      it "new/[]" do
        expect(struct.new(1, 2, 3).to_h).to eq typed_struct.new(1, 2, 3).to_h
        expect(struct[1, 2, 3].to_h).to eq typed_struct[1, 2, 3].to_h
      end
    end

    describe "instance methods" do
      let!(:struct) { Struct.new(:a, :b, :c) }
      let!(:typed_struct) { TypedStruct.new(a: Rbs("untyped"), b: Rbs("untyped"), c: Rbs("untyped")) }

      before do |example|
        testable_methods = Struct.instance_methods(false)
        unless (example.description.split(?/).map(&:to_sym) - testable_methods).empty?
          raise "unrecognised test: #{example.description}\navailable to test: #{testable_methods.join(?/)}"
        end
      end

      it "length/size/members/to_a/to_h/to_s/inspect/values" do |example|
        example.description.split(?/).map(&:to_sym).each do |method|
          expect(struct.new(1, 2, 3).send(method)).to eq typed_struct.new(1, 2, 3).send(method)
        end
      end

      it "==/eql?" do
        expect(struct.new(1, 2, 3)).to eq struct.new(1, 2, 3)
        expect(typed_struct.new(1, 2, 3)).to eq typed_struct.new(1, 2, 3)
        expect(struct.new(1, 2, 3)).to eql struct.new(1, 2, 3)
        expect(typed_struct.new(1, 2, 3)).to eql typed_struct.new(1, 2, 3)
      end

      it "hash" do
        expect(struct.new(1, 2, 3).hash).to eq struct.new(1, 2, 3).hash
        expect(typed_struct.new(1, 2, 3).hash).to eq typed_struct.new(1, 2, 3).hash
      end

      it "[]" do
        x = struct.new(1, 2, 3)
        y = typed_struct.new(1, 2, 3)
        expect(x[1]).to eq y[1]
        expect(x[:b]).to eq y[:b]
        expect(x[-2]).to eq y[-2]
      end

      it "[]=" do
        a = TypedStruct.new(
          { keyword_init: true },
          a: Rbs("String | Integer"),
          b: Rbs("String | Integer"),
          c: Rbs("String | Integer")
        ).new(a: "a", b: "b", c: "c")
        b = Struct.new(:a, :b, :c, keyword_init: true).new(a: "a", b: "b", c: "c")
        a[1], b[1] = 2, 2
        expect(a.values).to eq b.values
        a[:a], a[:c], b[:a], b[:c] = 3, 1, 3, 1
        expect(a.values).to eq b.values
        a[-2], b[-2] = 4, 4
        expect(a.values).to eq b.values
      end

      it "dig" do
        x = Struct.new(:a)
        y = TypedStruct.new(a: Hash)
        expect(x.new({b: {c: 1}}).dig(:a, :b, :c)).to be y.new({b: {c: 1}}).dig(:a, :b, :c)
      end

      it "values_at" do
        expect(struct.new(1, 2, 3).values_at(-2, 0, 2)).to eq typed_struct.new(1, 2, 3).values_at(-2, 0, 2)
      end

      it "each/each_pair" do
        expect(struct.new(1, 2, 3).each).to contain_exactly *typed_struct.new(1, 2, 3).each
        expect(struct.new(1, 2, 3).each_pair).to contain_exactly *typed_struct.new(1, 2, 3).each_pair
      end

      it "filter/select" do
        expect(struct.new(1, 2, 3).filter(&:even?)).to contain_exactly *typed_struct.new(1, 2, 3).filter(&:even?)
        expect(struct.new(1, 2, 3).select(&:even?)).to contain_exactly *typed_struct.new(1, 2, 3).select(&:even?)
      end
    end
  end

  context "when overriding native methods" do
    before { $stderr = StringIO.new }

    after { $stderr = STDERR }

    it "prints a warning for :class" do
      TypedStruct.new(class: String)
      expect($stderr.string).to start_with "*** WARNING *** property :class overrides a native method in TypedStruct"
      expect($stderr.string).to include __FILE__
    end

    it "prints a warning for :length" do
      TypedStruct.new(length: String)
      expect($stderr.string).to start_with "*** WARNING *** property :length overrides a native method in TypedStruct"
      expect($stderr.string).to include __FILE__
    end

    it "doesn't break if ignoring warning for :class" do
      x = TypedStruct.new({ keyword_init: true }, class: NilClass)
      expect(y = x.new(class: nil)).to be_truthy
      expect(y.class).to be_nil
      expect(y.__class__).to be_an_instance_of Class
    end
  end

  context "when passing options" do
    it "allows for default values" do
      x = TypedStruct.new(
        TypedStruct::Options.new(default: 5, keyword_init: true),
        int: Integer,
        str: String,
      )
      y = x.new str: "abc"
      expect(y.str).to eq "abc"
      expect(y.int).to eq 5
    end

    it "allows anything responding to [] to be passed as options" do
      x = TypedStruct.new(
        { default: 3, keyword_init: true },
        xyz: /foobar/,
        abc: :abc,
      )
      y = x.new abc: :abc, xyz: "foobarbaz"
      expect(y.abc).to eq :abc
      expect(y.xyz).to eq "foobarbaz"
    end

    it "breaks if a missing type and the type of the default don't match" do
      x = TypedStruct.new(
        TypedStruct::Options.new(default: 1, keyword_init: true),
        int: Integer,
        str: String,
      )
      expect { x.new(int: 4) }.to raise_error TypeError, "unexpected type Integer for :str (expected String)"
    end
  end

  context "when no options passed" do
    it "defaults to nil for missing properties" do
      x = TypedStruct.new abc: Rbs("String?")
      expect(x.new.abc).to be_nil
    end

    it "errors if the missing property cannot be nil" do
      x = TypedStruct.new abc: Rbs("String")
      expect { x.new }.to raise_error TypeError, "unexpected type NilClass for :abc (expected String)"
    end
  end

  context "when keyword_init is false" do
    it "treats keyword arguments as if they were positional arguments" do
      x = Struct.new(:int, :str, keyword_init: false)
      y = TypedStruct.new({ keyword_init: false }, int: Rbs("untyped"), str: Rbs("untyped"))
      expect(x.new(int: 5, str: "abc")).to have_attributes int: {int: 5, str: "abc"}, str: nil
      expect(y.new(int: 5, str: "abc")).to have_attributes int: {int: 5, str: "abc"}, str: nil
    end

    it "can be used to avoid unnecessary repetition" do
      Amount1 = TypedStruct.new({ keyword_init: true }, Amount: Integer)
      Amount2 = TypedStruct.new({ keyword_init: false }, Amount: Integer)
      expect { Amount1[5] }.to raise_error ArgumentError, "wrong number of arguments (given 1, expected 0)"
      expect { Amount2[Amount: 5] }.to raise_error TypeError, "unexpected type Hash for :Amount (expected Integer)"

      expect(Amount1[Amount: 5]).to have_attributes Amount: 5
      expect(Amount2[5]).to have_attributes Amount: 5
    end
  end

  context "when keyword_init is true" do
    it "disallows positional arguments" do
      x = Struct.new(:int, :str, keyword_init: true)
      expect { x.new(5, "abc") }.to raise_error ArgumentError
      x = TypedStruct.new({ keyword_init: true }, int: Integer, str: String)
      expect { x.new(5, "abc") }.to raise_error ArgumentError
    end

    it "can be used to enforce readability at the call site" do
      x = TypedStruct.new(
        { keyword_init: true },
        name: String,
        price: Integer,
        quantity: Integer,
        subtotal: Integer
      )
      expect{ x.new("x", 1, 2, 3) }.to raise_error ArgumentError
    end
  end
end

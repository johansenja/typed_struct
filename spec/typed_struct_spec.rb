# frozen_string_literal: true

RSpec.describe TypedStruct do
  it "has a version number" do
    expect(TypedStruct::VERSION).not_to be nil
  end

  context "on overriding native methods" do
    before { $stdout = StringIO.new }

    after { $stdout = STDOUT }

    it "prints a warning for :class" do
      TypedStruct.new class: String
      expect($stdout.string).to start_with "*** WARNING *** property :class overrides a native method in TypedStruct"
      expect($stdout.string).to include __FILE__
    end

    it "prints a warning for :length" do
      TypedStruct.new length: String
      expect($stdout.string).to start_with "*** WARNING *** property :length overrides a native method in TypedStruct"
      expect($stdout.string).to include __FILE__
    end

    it "doesn't break if ignoring warning for :class" do
      x = TypedStruct.new class: NilClass
      expect(y = x.new(class: nil)).to be_truthy
      expect(y.class).to be_nil
      expect(y.__class__).to be_an_instance_of Class
    end
  end

  context "when passing options" do
    it "allows for default values" do
      x = TypedStruct.new(
        TypedStruct::Options.new(default: 5),
        int: Integer,
        str: String,
      )
      y = x.new str: "abc"
      expect(y.str).to eq "abc"
      expect(y.int).to eq 5
    end

    it "allows anything responding to [] to be passed as options" do
      x = TypedStruct.new(
        { default: 3 },
        xyz: /foobar/,
        abc: :abc,
      )
      y = x.new abc: :abc, xyz: "foobarbaz"
      expect(y.abc).to eq :abc
      expect(y.xyz).to eq "foobarbaz"
    end

    it "breaks if a missing type and the type of the default don't match" do
      x = TypedStruct.new(
        TypedStruct::Options.new(default: 1),
        int: Integer,
        str: String,
      )

      expect { x.new(int: 4) }.to raise_error "Unexpected type Integer for :str (expected String)"
    end
  end

  context "when no options passed" do
    it "defaults to nil for missing properties" do
      x = TypedStruct.new abc: Rbs("String?")
      expect(x.new.abc).to be_nil
    end

    it "errors if the missing property cannot be nil" do
      x = TypedStruct.new abc: Rbs("String")
      expect { x.new }.to raise_error "Unexpected type NilClass for :abc (expected String)"
    end
  end
end

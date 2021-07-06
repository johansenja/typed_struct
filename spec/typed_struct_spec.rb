# frozen_string_literal: true

RSpec.describe TypedStruct do
  it "has a version number" do
    expect(TypedStruct::VERSION).not_to be nil
  end

  it "works for a variety of property types" do
    Other = TypedStruct.new x: :y
    Item = TypedStruct.new a: 1,
                           b: String,
                           c: Rbs("Array[Symbol]"),
                           d: /abc/,
                           e: (0..5),
                           f: Other,
                           g: "foo",
                           h: Rbs("Array[Other]")
    expect(
      Item.new(a: 1,
               b: "baz",
               c: %i[oo aa],
               d: "abcdef",
               e: 3,
               f: Other.new(x: :y),
               g: "foo",
               h: [Other.new(x: :y)])
    ).to be_truthy
  end

  context "for key strictness" do
    it "doesn't error on extra properties" do
      Item1 = TypedStruct.with(strict_keys: false).new(foo: String)
      expect(Item1.new(foo: "", bar: 0)).to be_truthy
    end

    it "errors with extra properties (explicit)" do
      Item2 = TypedStruct.with(strict_keys: true).new(foo: String)
      expect { Item2.new(foo: "", bar: 0) }.to raise_error ArgumentError
    end

    it "errors with extra properties (by default)" do
      Item3 = TypedStruct.new(foo: String)
      expect { Item3.new(foo: "", bar: 0) }.to raise_error ArgumentError
    end

    it "can still raise type errors" do
      Item4 = TypedStruct.with(strict_keys: false).new(foo: String)
      expect { Item4.new(foo: :abc) }.to raise_error TypedStruct::TypeError
    end
  end
end

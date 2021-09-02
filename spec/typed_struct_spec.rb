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
end

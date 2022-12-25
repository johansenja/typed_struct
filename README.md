# TypedStruct

A Typed Struct is a lightweight data structure inspired by [Dry Struct](https://github.com/dry-rb/dry-struct), which allows for reading and writing properties while making use of a flexible and powerful type checking system, which also incorporates Ruby's [RBS](https://github.com/ruby/rbs/) for type definitions. 

## Example

```ruby
require 'typed_struct' # unless using rails

User = TypedStruct.new name: String, # an instance of String
                       age: Integer, # an instance of Integer
                       username: /\w{4,}/, # must match given Regexp
                       rating: (0..5), # must be value from 0 to 5
                       type: "User", # must by a string with value "User"
                       interests: Rbs("Array[String]"), # an RBS generic type (an Array of Strings)
                       preferences: Rbs("{ opt_out_of_emails: bool, additional: untyped }") # RBS record type

clive = User.new name: "Clive",
                 age: 22,
                 interests: %w[surfing skiing],
                 preferences: { opt_out_of_emails: true, additional: { preferred_theme: :dark } },
                 type: "User",
                 rating: 4,
                 username: "cliveabc"

clive.age # 22
clive.age = '22' # => Error
clive.preferences = { "opt_out_of_emails" => true, "additional" => nil } # error - type mismatch, not Symbol keys
clive.freeze # no more changes can be made
```
Optionally specify a default member value:
```ruby
3.2.0 :001 > TypedStruct.new({ default: 5 }, int: Integer, str: String)
 => #<Class:0x00007faeed58ab58>
3.2.0 :002 > _.new(str: "abc")
 => #<struct  int=5, str="abc">
```
Pass [`Struct` options](https://ruby-doc.org/core-2.5.0/Struct.html#method-c-new) similarly:
```ruby
3.2.0 :001 > Struct.new("User", :name)
 => Struct::User
3.2.0 :002 > TypedStruct.new({ class_name: "User" }, name: String)
 => TypedStruct::User
3.2.0 :003 > Struct.new(:name, keyword_init: true)
 => #<Class:0x00007f86d618a1f0>(keyword_init: true)
3.2.0 :004 > TypedStruct.new({ keyword_init: true }, name: String)
 => #<Class:0x00007f86d618b190>(keyword_init: true)
```
Configure `TypedStruct.default_keyword_init` to change the default `keyword_init` value globally:
```ruby
3.2.0 :001 > TypedStruct.new(int: Integer, str: String)
 => #<Class:0x00007f6d32701f60>
3.2.0 :002 > TypedStruct.default_keyword_init = true
 => true
3.2.0 :003 > TypedStruct.new(int: Integer, str: String)
 => #<Class:0x00007f6d32706b00>(keyword_init: true)
3.2.0 :004 > TypedStruct.new({ keyword_init: false }, int: Integer, str: String)
 => #<Class:0x00007f6d32700fc0>
```

Note that a `TypedStruct` inherits from `Struct` directly, so anything from `Struct` is also available in `TypedStruct` - see [Struct docs](https://ruby-doc.org/core-3.0.1/Struct.html) for more info.

**See [RBS reference](https://github.com/ruby/rbs/blob/3c046c77c3006211a1a14eedc35221ac4198f788/docs/syntax.md) for more info on writing RBS types**

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'typed_struct'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install typed_struct

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/johansenja/typed_struct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

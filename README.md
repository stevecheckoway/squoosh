# Squoosh

Minifies HTML, JavaScript, and CSS, including inline JavaScript and CSS.

CSS minification is handled by [Sass](http://www.rubydoc.info/gems/sass)
whereas JavaScript minification is handled by
[Uglifier](http://www.rubydoc.info/gems/uglifier) which requires node.js.

HTML minification is handled as follows. First, an HTML 5 (which really means
the [WHATWG HTML](https://html.spec.whatwg.org/multipage/) living standard)
parser constructs a DOM as specified by the standard. Next, semantically
meaningless [inter-element whitespace
nodes](https://html.spec.whatwg.org/multipage/dom.html#inter-element-whitespace)
are removed from the DOM and semantically meaningfull runs of whitespace are
compressed to single spaces, except in `pre`, `textarea`, and
[foreign](https://html.spec.whatwg.org/multipage/syntax.html#elements-2) elements.
Then, inline JavaScript and CSS are compressed using Sass and Uglifier.
Finally, the DOM is serialized, compressing
[attributes](https://html.spec.whatwg.org/multipage/syntax.html#attributes-2)
where possible and omitting [optional start and end
tags](https://html.spec.whatwg.org/multipage/syntax.html#optional-tags) where
possible.

Unlike some other HTML minifiers, Squoosh uses neither Java nor [regular
expressions](http://stackoverflow.com/a/1732454) to parse HTML.

## Limitations
Squoosh will not minify

- HTML 4 and earlier;
- XHTML, any version;
- [MathML](https://www.w3.org/TR/MathML3/) elements; nor
- [SVG](https://www.w3.org/TR/SVG11/) elements.

## Installation

*The generic installation instructions in this section probably won't work
until this is uploaded to rubygems, at which point I will have deleted this
note (hopefully).*

Add this line to your application's Gemfile:

```ruby
gem 'squoosh'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install squoosh

## Usage

The three basic minification functions are

- `Squoosh::minify_html`
- `Squoosh::minify_js`
- `Squoosh::minify_css`

The `Squoosher` class allows some options, but those are likely to change.

### Using with Jekyll

Create a `_plugins/squoosh.rb` file with the contents

```ruby
require 'squoosh'

Jekyll::Hooks.register [:documents, :pages], :post_render, priority: :high do |doc|
  case File.extname(doc.destination('./'))
  when '.html', '.htm'
    doc.output = Squoosh::minify_html doc.output
  when '.js'
    doc.output = Squoosh::minify_js doc.output
  end
end
```

CSS minification could be handled similarly, or `foo.css` files could simply
be renamed to `foo.scss` and 

```yaml
sass:
  style: compressed
```

added to `_config.yml`.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/stevecheckoway/squoosh.


## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).


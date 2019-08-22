# Squoosh

Minifies HTML, JavaScript, and CSS, including inline JavaScript and CSS.

[![Travis-CI Build
Status](https://travis-ci.org/stevecheckoway/squoosh.svg)](https://travis-ci.org/stevecheckoway/squoosh)

CSS minification is handled by [Sassc](http://www.rubydoc.info/gems/sassc)
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
Then, inline JavaScript and CSS are compressed using Sassc and Uglifier.
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

Add this line to your application's Gemfile:

```ruby
gem 'squoosh'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install squoosh

## Usage

You can read the documentation
[here](https://www.rubydoc.info/github/stevecheckoway/squoosh/).

The three basic minification functions are

- `Squoosh::minify_html`
- `Squoosh::minify_js`
- `Squoosh::minify_css`

The `Squoosher` class caches (in memory) minified JavaScript and CSS which can
significantly speed up minifying HTML with repeated scripts and style sheets.

### Using with Jekyll

Create a `_plugins/squoosh.rb` file with the contents

```ruby
# frozen_string_literal: true

if Jekyll.env == 'deploy'
  require 'squoosh'

  squoosher = Squoosh::Squoosher.new
  Jekyll::Hooks.register(%i[documents pages],
                         :post_render, priority: :high) do |doc|
    case File.extname(doc.destination('./'))
    when '.html', '.htm'
      doc.output = squoosher.minify_html(doc.output)
    when '.js'
      doc.output = squoosher.minify_js(doc.output)
    end
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


# frozen_string_literal: true

require "spec_helper"

OMIT_TAG_OPTIONS = {
  omit_tags: true,
  compress_spaces: false,
  remove_comments: false,
  minify_javascript: false,
  minify_css: false
}.freeze

NO_OMIT_TAG_OPTIONS = {
  omit_tags: false,
  compress_spaces: false,
  remove_comments: false,
  minify_javascript: false,
  minify_css: false
}.freeze

COMMENT_OPTIONS = {
  omit_tags: true,
  compress_spaces: false,
  remove_comments: true,
  minify_javascript: false,
  minify_css: false
}.freeze

HTML_OPTIONS = {
  omit_tags: true,
  compress_spaces: true,
  remove_comments: true,
  minify_javascript: false,
  minify_css: false
}.freeze

CSS_OPTIONS = {
  omit_tags: true,
  compress_spaces: false,
  remove_comments: false,
  minify_javascript: false,
  minify_css: true
}.freeze

JS_OPTIONS = {
  omit_tags: true,
  compress_spaces: false,
  remove_comments: false,
  minify_javascript: true,
  minify_css: false
}.freeze

W3SCHOOLS_CSS = <<~CSS_EOF
  .flex-container {
    display: flex;
    flex-wrap: wrap;
    background-color: DodgerBlue;
  }

  .flex-container > div {
    background-color: #f1f1f1;
    width: 100px;
    margin: 10px;
    text-align: center;
    line-height: 75px;
    font-size: 30px;
  }
CSS_EOF

W3SCHOOLS_CSS_EXPECTED = ".flex-container{display:flex;flex-wrap:wrap;" \
                         "background-color:DodgerBlue}.flex-container>div{background-color:#f1f1f1;" \
                         "width:100px;margin:10px;text-align:center;line-height:75px;font-size:30px}"

JS = <<~JS_EOF
  function foo() {
    document.getElementById('foo').innerHTML = "Hello world!";
    return 10;
  }
  /* Alert! */
  alert( foo() );
JS_EOF

JS_MATCH = "alert(foo())"

DOCTYPE = "<!DOCTYPE html>"

def omit(tag, htmls)
  htmls.each do |html|
    it "omits <#{tag}> in #{code}#{html}" do
      expect(Squoosh.minify_html(DOCTYPE + html, OMIT_TAG_OPTIONS))
        .not_to match "<#{tag}[ >]"
    end
  end
end

def keep(tag, htmls)
  htmls.each do |html|
    it "keeps <#{tag}> in #{code}#{html}" do
      expect(Squoosh.minify_html(DOCTYPE + html, OMIT_TAG_OPTIONS))
        .to match "<#{tag}[ >]"
    end
  end
end

def no_omit(tag, htmls)
  htmls.each do |html|
    it "does not omit <#{tag}> in #{code}#{html}" do
      expect(Squoosh.minify_html(DOCTYPE + html, NO_OMIT_TAG_OPTIONS))
        .to match "<#{tag}[ >]"
    end
  end
end

# Ensure that the spaces remain, even after being compressed.
def keep_spaces(htmls)
  htmls.each do |html|
    it "keeps spaces in #{code}#{html}" do
      html = DOCTYPE + html
      expect(Squoosh.minify_html(html, HTML_OPTIONS)).to eq html
    end
  end
end

def remove_comments(comment_start, htmls)
  htmls.each do |html|
    it "removes comments in #{code}#{html}" do
      html = DOCTYPE + html
      expect(Squoosh.minify_html(html, COMMENT_OPTIONS))
        .not_to include comment_start
    end
  end
end

def exact_match(prefix, htmls, options)
  htmls.each do |html|
    it "#{prefix} in #{code}#{html[0]}" do
      input = DOCTYPE + html[0]
      output = DOCTYPE + html[1]
      expect(Squoosh.minify_html(input, options)).to eq output
    end
  end
end

describe Squoosh do
  describe ".minify_html" do
    context "when omitting tags" do
      # An html element's start tag may be omitted if the first thing inside the
      # html element is not a comment.
      omit "html", ["<html></html>",
        "<html><head></head></html>",
        "<html> <head></head></html>",
        "<html><body></body></html>",
        "<html>Hello!</html>",
        "<html> Hello!</html>"]

      keep "html", ["<html><!-- --></html>",
        '<html lang="en"></html>']

      # An html element's end tag may be omitted if the html element is not
      # immediately followed by a comment.
      omit "/html", ["<html></html>"]

      keep "/html", ["<html></html><!-- -->"]

      # A head element's start tag may be omitted if the element is empty, or if
      # the first thing inside the head element is an element.
      omit "head", ["<head></head>",
        "<head><title></title></head>"]
      keep "head",
        ["<head id=X></head>",
          "<head><!-- -->" \
          '<meta http-equiv="Content-Type" content="text/html">' \
          "</head>"]

      # A head element's end tag may be omitted if the head element is not
      # immediately followed by a space character or a comment.
      # [There seems to be no way to represent a space after </head> in HTML, it
      # appears in the <body> instead. -- sfc]
      omit "/head", ["<head><title></title></head><body>",
        "<head><title></title></head><p>",
        "<head><title></title></head>X"]
      keep "/head", ["<head><title></title></head><!-- --><body>"]

      # A body element's start tag may be omitted if the element is empty, or if
      # the first thing inside the body element is not a space character or a
      # comment, except if the first thing inside the body element is a meta,
      # link, script, style, or template element.
      omit "body", ["<body></body>",
        "<body>",
        "<body><p>X",
        "<body>X"]
      keep "body", ["<body> X",
        "<body><!-- -->",
        "<body><meta>",
        "<body><link>",
        "<body><script></script>",
        "<body><style></style>",
        "<body><template></template>",
        "<body id=X>"]

      # A body element's end tag may be omitted if the body element is not
      # immediately followed by a comment.
      omit "/body", ["<html><body></body></html>",
        "<html><body></body> </html>",
        "<body></body>"]
      keep "/body", ["<html><body></body><!-- --></html>"]

      # An li element's end tag may be omitted if the li element is immediately
      # followed by another li element or if there is no more content in the
      # parent element.
      omit "/li", ["<ol><li></li><li></li></ol>",
        "<ol><li></li> <li></li></ol>",
        "<ol><li></li><!-- --><li></li></ol>",
        "<ol><li></li> <!-- --><!-- --> <!-- --><li></li></ol>",
        "<ol><li></li> </ol>",
        "<ol><li></li><!-- --></ol>",
        "<ol><li></li> <!-- --><!-- --> <!-- --></ol>"]

      keep "/li", ["<ol><li></li><script></script></ol>",
        "<ol><li></li>text<li></ol>"]

      # A dt element's end tag may be omitted if the dt element is immediately
      # followed by another dt element or a dd element.
      omit "/dt", ["<dl><dt></dt><dt></dt><dd></dd></dl>",
        "<dl><dt> </dt><dt></dt><!-- --><dd></dd></dl>"]

      keep "/dt", ["<dl><dt></dt><script></script></dl>",
        "<dl><dt></dt></dl>",
        "<dl><dt></dt>X<dd></dd></dl>"]

      # A dd element's end tag may be omitted if the dd element is immediately
      # followed by another dd element or a dt element, or if there is no more
      # content in the parent element.
      omit "/dd", ["<dl><dt></dt><dd></dd><dd></dd></dl>",
        "<dl><dt></dt><dd></dd> <dd></dd></dl>",
        "<dl><dt></dt><dd></dd><!-- --><dd></dd></dl>",
        "<dl><dt></dt><dd></dd><dt></dt><dd></dd></dl>",
        "<dl><dt></dt><dd></dd> <dt></dt><dd></dd></dl>",
        "<dl><dt></dt><dd></dd><!-- --><dt></dt><dd></dd></dl>",
        "<dl><dt></dt><dd></dd> </dl>",
        "<dl><dt></dt><dd></dd><!-- --></dl>"]

      keep "/dd", ["<dl><dt></dt><dd></dd><script></script>",
        "<dl><dt></dt><dd></dd>X<dt></dt></dl>"]

      # A p element's end tag can be omitted if the p element is immediately
      # followed by an address, article, aside, blockquote, details, div,
      # dl, fieldset, figcaption, figure, footer, form, h1, h2, h3, h4, h5,
      # h6, header, hgroup, hr, main, menu, nav, ol, p, pre, section, table,
      # or ul element, or if there is no more content in the parent element
      # and the parent element is an HTML element that is not an a, audio,
      # del, ins, map, noscript, or video element, or an autonomous custom
      # element.
      omit "/p", (["<p></p><hr>",
        "<p></p> <hr>",
        "<p></p><!-- --><hr>",
        "<p></p>",
        "<p></p> ",
        "<div><p></p></div>",
        "<div><p></p> </div>",
        "<div><p></p><!-- --></div>",
        "<p></p><!-- -->"] +
                  %w[address article aside blockquote details div dl fieldset
                    figcaption figure footer form h1 h2 h3 h4 h5 h6 header
                    hgroup main menu nav ol p pre section table ul]
                    .flat_map do |t|
                      ["<p></p><#{t}></#{t}>",
                        "<p></p> <#{t}></#{t}>",
                        "<p></p><!-- --><#{t}></#{t}>"]
                    end)

      # We can't test <noscript><p></p></noscript> because we can't actually
      # specify that in HTML.
      keep "/p", (["<p></p><script></script>",
        "<p></p> <script></script>",
        "<p></p><!-- --><script></script>"] +
                   %w[a audio del ins map video].flat_map do |t|
                     ["<#{t}><p></p></#{t}>",
                       "<#{t}><p></p> </#{t}>",
                       "<#{t}><p></p><!-- --></#{t}>"]
                   end)

      # An rb element's end tag may be omitted if the rb element is immediately
      # followed by an rb, rt, rtc or rp element, or if there is no more content
      # in the parent element.
      keep "/rb", ["<ruby><rb>漢</rb>字</ruby>",
        "<ruby><rb>漢</rb><span></span></ruby>"]
      omit "/rb", ["<ruby><rb>漢</rb></ruby>",
        "<ruby><rb>漢</rb><rb>字</rb></ruby>",
        "<ruby><rb>漢</rb><rt>kan</rt></ruby>",
        "<ruby><rb>漢</rb><rb>字</rb><rtc><rt>kanji</rt></rtc></ruby>",
        "<ruby><rb>漢</rb><rp>(</rp><rt>kan</rt><rp>)</rp></ruby>"]

      # An rt element's end tag may be omitted if the rt element is immediately
      # followed by an rb, rt, rtc, or rp element, or if there is no more
      # content in the parent element.
      keep "/rt", ["<ruby><rt>kan</rt>字</ruby>",
        "<ruby><rt>kan</rt><span></span></ruby>"]
      omit "/rt", ["<ruby><rb>漢</rb><rt>kan</rt></ruby>",
        "<ruby><rb>漢</rb><rt>kan</rt><rb>字</rb><rt>ji</rt></ruby>",
        "<ruby><rb>漢</rb><rt>kan</rt><rb>字</rb><rt>ji</rt>" \
        "<rtc><rt>kanji></rt></rtc></ruby>",
        "<ruby><rb>漢</rb><rp>(</rp><rt>kan</rt><rp>)</rp></ruby>"]

      # An rtc element's end tag may be omitted if the rtc element is
      # immediately followed by an rb, rtc or rp element, or if there is no more
      # content in the parent element.
      keep "/rtc", ["<ruby><rtc><rt>kanji</rt></rtc>字</ruby>",
        "<ruby><rtc><rt>kanji</rt></rtc><span></span></ruby>"]
      omit "/rtc", ["<ruby>漢字<rtc><rt>kanji></rt></rtc></ruby>",
        "<ruby>漢字<rtc><rt>kanji></rt></rtc></ruby>",
        "<ruby><rtc></rtc><rtc></rtc></ruby>",
        "<ruby><rtc></rtc><rp></rp></ruby>"]

      # An rp element's end tag may be omitted if the rp element is immediately
      # followed by an rb, rt, rtc or rp element, or if there is no more content
      # in the parent element.
      keep "/rp", ["<ruby><rp></rp>字</ruby>",
        "<ruby><rp></rp><span></span></ruby>"]
      omit "/rp", ["<ruby><rp></rp></ruby>",
        "<ruby><rp></rp><rb></rb></ruby>",
        "<ruby><rp></rp><rt></rt></ruby>",
        "<ruby><rp></rp><rtc></rtc></ruby>",
        "<ruby><rp></rp><rp></rp></ruby>"]

      # An optgroup element's end tag may be omitted if the optgroup element is
      # immediately followed by another optgroup element, or if there is no more
      # content in the parent element.
      omit "/optgroup",
        ["<select><optgroup></optgroup></select>",
          "<select><optgroup></optgroup><optgroup></optgroup></select>"]

      # An option element's end tag may be omitted if the option element is
      # immediately followed by another option element, or if it is immediately
      # followed by an optgroup element, or if there is no more content in the
      # parent element.
      omit "/option",
        ["<select><option></option></select>",
          "<select><option></option><option></option></select>",
          "<select><option></option><optgroup></optgroup></select>"]

      # A colgroup element's start tag may be omitted if the first thing inside
      # the colgroup element is a col element, and if the element is not
      # immediately preceded by another colgroup element whose end tag has been
      # omitted. (It can't be omitted if the element is empty.)
      omit "colgroup",
        ["<table><colgroup><col><col></colgroup></table>",
          "<table><colgroup><!-- --><col><col></colgroup></table>"]

      keep "colgroup",
        ["<table><colgroup><!-- --></colgroup></table>",
          "<table><colgroup> </colgroup></table>",
          "<table><colgroup></colgroup></table>"]

      # A colgroup element's end tag may be omitted if the colgroup element is
      # not immediately followed by a space character or a comment.
      omit "/colgroup",
        ["<table><colgroup><col></colgroup><tr></tr></table>"]

      keep "/colgroup",
        ["<table><colgroup><col></colgroup> <tr></tr></table>",
          "<table><colgroup><col></colgroup><!-- --></table>"]

      exact_match("keep second <colgroup>",
        [["<table><colgroup><col></colgroup><colgroup><col></colgroup></table>",
          "<table><col><colgroup><col></table>"]],
        OMIT_TAG_OPTIONS)

      # A thead element's end tag may be omitted if the thead element is
      # immediately followed by a tbody or tfoot element.
      omit "/thead",
        ["<table><thead></thead><tbody></tbody></table>",
          "<table><thead></thead> <tbody></tbody></table>",
          "<table><thead></thead><!-- --><tbody></tbody></table>",
          "<table><thead></thead><tfoot></tfoot></table>",
          "<table><thead></thead> <tfoot></tfoot></table>",
          "<table><thead></thead><!-- --><tfoot></tfoot></table>"]

      keep "/thead",
        ["<table><thead></thead><script></script></thead></table>",
          "<table><thead></thead> <script></script></thead></table>",
          "<table><thead></thead><!-- --><script></script></thead></table>",
          "<table><thead></thead></thead></table>",
          "<table><thead></thead> </thead></table>",
          "<table><thead></thead><!-- --></thead></table>"]

      # A tbody element's start tag may be omitted if the first thing inside the
      # tbody element is a tr element, and if the element is not immediately
      # preceded by a tbody, thead, or tfoot element whose end tag has been
      # omitted. (It can't be omitted if the element is empty.)
      omit "tbody",
        ["<table><tbody><tr></tr></tbody></table>",
          "<table><tfoot></tfoot> <tbody><tr></tr></tbody></table>",
          "<table><tfoot></tfoot><!-- --><tbody><tr></tr></tbody></table>"]

      keep "tbody",
        ["<table><thead></thead> <tbody><tr></tr></tbody></table>",
          "<table><thead></thead><!-- --><tbody><tr></tr></tbody></table>"]

      # A tbody element's end tag may be omitted if the tbody element is
      # immediately followed by a tbody or tfoot element, or if there is no more
      # content in the parent element.
      omit "/tbody", ["<table><tbody></tbody><tbody></tbody></table>",
        "<table><tbody></tbody><tfoot></tfoot></table>",
        "<table><tbody></tbody></table>",
        "<table><tbody></tbody> </table>",
        "<table><tbody></tbody><!-- --></table>"]

      keep "/tbody", ["<table><tbody></tbody><script></script></table>"]

      # A tfoot element's end tag can be omitted if there is no more content in
      # the parent element.
      omit "/tfoot", ["<table><tfoot></tfoot> </table>",
        "<table><tfoot></tfoot><!-- --></table>"]

      keep "/tfoot", ["<table><tfoot></tfoot><tfoot></tfoot></table>"]

      # A tr element's end tag may be omitted if the tr element is immediately
      # followed by another tr element, or if there is no more content in the
      # parent element.
      omit "/tr", ["<table><tr></tr><tr></tr></table>",
        "<table><tr></tr> </table>",
        "<table><tr></tr><!-- --></table>"]

      keep "/tr", ["<table><tr></tr><script></script></table>"]

      # A td element's end tag may be omitted if the td element is immediately
      # followed by a td or th element, or if there is no more content in the
      # parent element.
      omit "/td", ["<table><tr><td></td><td></td></tr></table>",
        "<table><tr><td></td><th></th></tr></table>",
        "<table><tr><td></td> </tr></table>",
        "<table><tr><td></td><!-- --></tr></table>"]

      keep "/td", ["<table><tr><td></td><script></script></table>"]

      # A th element's end tag may be omitted if the th element is immediately
      # followed by a td or th element, or if there is no more content in the
      # parent element.
      omit "/th", ["<table><tr><th></th><td></td></tr></table>",
        "<table><tr><th></th><th></th></tr></table>",
        "<table><tr><th></th> </tr></table>",
        "<table><tr><th></th><!-- --></tr></table>"]

      keep "/th", ["<table><tr><th></th><script></script></table>"]

      exact_match("compress empty, self-closing elements",
        [["<svg></svg>", "<svg/>"],
          ['<svg id="foo"></svg>', "<svg id=foo />"],
          ['<svg id="x y"></svg>', '<svg id="x y"/>'],
          ["<math></math>", "<math/>"],
          ['<math id="foo"></math>', "<math id=foo />"],
          ['<math id="x y"></math>', '<math id="x y"/>']],
        HTML_OPTIONS)
    end

    # Make sure we keep tags when we aren't omitting them.
    context "when not omitting tags" do
      no_omit("html", ["<!-- -->", "<head>", "<body>"])
      no_omit("/html", ["<!-- -->", "<head>", "<body>"])
      no_omit("head", ["<meta>", "<script></script>"])
      no_omit("/head", ["<meta>", "<script></script>"])
      no_omit("body", ["<div></div>", "<p>hi<p>there"])
      no_omit("/body", ["<div></div>", "<p>hi<p>there"])
      no_omit("/p", ["<p>foo", "<p>foo<h1>bar</h1>"])
      no_omit("/svg", ["<svg/>", "<svg></svg>", "<svg id=x></svg>"])
      no_omit("/math", ["<math/>", "<math></math>", "<math id=x></math>"])
    end

    # Do not remove spaces between links.
    context "when compressing spaces" do
      keep_spaces(["<p><a href=example.com>Foo</a> <a href=example.com>Bar</a>",
        "<p>Foo <a href=example.com>Bar</a>",
        "<p><a href=example.com>Foo</a> Bar"])

      exact_match("removes spaces",
        [["<div> <p> Foo <p> Bar </div>",
          "<div><p>Foo<p>Bar</div>"]],
        HTML_OPTIONS)

      exact_match("combines spaces",
        [["foo &#x20; bar", "foo bar"],
          ["foo <!-- --> bar", "foo bar"]],
        HTML_OPTIONS)

      # A single newline may be placed immediately after the start tag of pre
      # and textarea elements. This does not affect the processing of the
      # element. The otherwise optional newline must be included if the
      # element's contents themselves start with a newline (because otherwise
      # the leading newline in the contents would be treated like the optional
      # newline, and ignored).
      elms = %w[pre textarea]
      elms.each do |elm|
        it "keeps two newlines at the start of #{elm}" do
          html = "<!DOCTYPE html><#{elm}>\n\nFoo\n</#{elm}>"
          expect(Squoosh.minify_html(html, HTML_OPTIONS)).to eq html
        end
      end

      elms = %w[pre textarea]
      elms.each do |elm|
        it "removes a single newline at the start of #{elm}" do
          input = DOCTYPE + "<#{elm}>\nFoo\n</#{elm}>"
          output = DOCTYPE + "<#{elm}>Foo\n</#{elm}>"
          expect(Squoosh.minify_html(input, HTML_OPTIONS)).to eq output
        end
      end

      exact_match("compresses attributes",
        [[%(<a  id="bare"  href='/foo'  ></a>),
          "<a id=bare href=/foo></a>"],
          [%(<p id='"quotes"'>), %(<p id='"quotes"'>)],
          [%(<p id="&quot;x&quot;">), %(<p id='"x"'>)],
          [%(<p id='&apos;x&apos;'>), %(<p id="'x'">)],
          [%(<p id="&quot;x&apos;">), %(<p id="&#34;x'">)],
          ['<p data-model-target="">', "<p data-model-target>"]],
        HTML_OPTIONS)
    end

    # Remove non-loud comments.
    context "when removing comments" do
      remove_comments("<!--",
        ["<!---->",
          "<!-- -->",
          "<body><!-- EOF",
          "</html><!---->",
          "</body><!-->",
          "<!--->",
          "<!-->"])
      remove_comments('<\?', ['<?php echo "bogus comment"; ?>'])
      remove_comments("</1337", ["</1337 bogus comment>"])

      exact_match("keeps loud comments",
        [["<!-- !LOUD! --><!-- quiet! -->",
          "<!-- !LOUD! -->"]],
        COMMENT_OPTIONS)
      exact_match("keeps comment-like text",
        [["<title><!-- RCDATA --></title>",
          "<title>&lt;!-- RCDATA --&gt;</title>"],
          ["<script><!-- </script>-->",
            "<script><!-- </script>--&gt;"],
          ["<noframes><!-- RAWTEXT --></noframes>",
            "<noframes><!-- RAWTEXT --></noframes>"],
          ["<script><!-- --></script>",
            "<script><!-- --></script>"]],
        COMMENT_OPTIONS)
      exact_match("combines text nodes", [["foo<!-- -->bar", "foobar"]], COMMENT_OPTIONS)
    end

    context "when compressing CSS" do
      # Inline styles.
      exact_match("compresses style attributes",
        [['<div style="clear: both"></div>', "<div style=clear:both></div>"]],
        CSS_OPTIONS)

      # Style elements.
      exact_match("compresses style elements",
        [["<style>\n#{W3SCHOOLS_CSS}\n</style>",
          "<style>#{W3SCHOOLS_CSS_EXPECTED}</style>"]],
        CSS_OPTIONS)
    end

    context "when compressing script" do
      # Event handlers.
      events = %w[click load blur]
      events.each do |event|
        html = "<p on#{event}='foo( 10 )'>"
        expected = "<p on#{event}=foo(10)>"
        it "compress script in #{code}#{html}" do
          expect(Squoosh.minify_html(DOCTYPE + html, JS_OPTIONS))
            .to eq DOCTYPE + expected
        end
      end

      # Script elements.
      jshtml = "<script>#{JS}</script>"
      it "compress script elements in #{code}#{jshtml}" do
        expect(Squoosh.minify_html(DOCTYPE + jshtml, JS_OPTIONS))
          .to include JS_MATCH
      end

      # Check that "</scr" + "ipt>" is compressed to "</script>"...
      onclickhtml = %(<p onclick='foo("</scr" + "ipt>")'>)
      it "produces </script> in #{code}#{onclickhtml}" do
        expect(Squoosh.minify_html(DOCTYPE + onclickhtml, JS_OPTIONS))
          .to include 'foo("</script>")'
      end

      # ...except inside a script element.
      scripthtml = '<script>x="</scr" + "ipt>"</script>'
      it "does not produce </script> in #{code}#{scripthtml}" do
        expect(Squoosh.minify_html(DOCTYPE + scripthtml, JS_OPTIONS))
          .not_to match(%r{</script>.*</script>})
      end
    end

    # Namespaced attributes in foreign elements.
    svg = <<~SVG_EOF
      <svg height="30" width="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        <a xlink:href="https://example.com">
          <text x="0" y="15" fill="red">Example</text>
        </a>
      </svg>
    SVG_EOF
    it "preserves attribute namespaces in #{code}#{svg}" do
      expect(Squoosh.minify_html(DOCTYPE + svg, HTML_OPTIONS))
        .to include(" xmlns=http://www.w3.org/2000/svg")
        .and include(" xmlns:xlink=http://www.w3.org/1999/xlink")
        .and include(" xlink:href=https://example.com")
    end

    math = "<math><mi xml:lang=en xlink:href=foo></mi></math>"
    it "preserves attribute namespaces in #{code}#{math}" do
      expect(Squoosh.minify_html(DOCTYPE + math, HTML_OPTIONS))
        .to eq(DOCTYPE + math)
    end
  end

  # Minify CSS.
  describe ".minify_css" do
    it "minifies CSS" do
      expect(Squoosh.minify_css(W3SCHOOLS_CSS, CSS_OPTIONS))
        .to eq W3SCHOOLS_CSS_EXPECTED
    end
  end

  # Minify JavaScript.
  describe ".minify_js" do
    it "minifies JavaScript" do
      expect(Squoosh.minify_js(JS, JS_OPTIONS)).to include JS_MATCH
    end
  end

  describe "Squoosher" do
    describe ".new" do
      it "throws on invalid options" do
        options = {foobar: true}
        expect { Squoosh::Squoosher.new(options) }
          .to raise_error(ArgumentError)
      end
    end
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:

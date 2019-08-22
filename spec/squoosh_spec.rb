# frozen_string_literal: true

require 'spec_helper'

OMIT_TAG_OPTIONS = {
  omit_tags: true,
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

W3SCHOOLS_CSS_EXPECTED = '.flex-container{display:flex;flex-wrap:wrap;' \
  'background-color:DodgerBlue}.flex-container>div{background-color:#f1f1f1;' \
  'width:100px;margin:10px;text-align:center;line-height:75px;font-size:30px}'

def omit(tag, htmls)
  context "omit <#{tag}> in" do
    htmls.each do |html|
      it html do
        expect(Squoosh.minify_html('<!DOCTYPE html>' + html,
                                   OMIT_TAG_OPTIONS)).not_to match "<#{tag}[ >]"
      end
    end
  end
end

def keep(tag, htmls)
  context "keep <#{tag}> in" do
    htmls.each do |html|
      it html do
        expect(Squoosh.minify_html('<!DOCTYPE html>' + html,
                                   OMIT_TAG_OPTIONS)).to match "<#{tag}[ >]"
      end
    end
  end
end

# Ensure that the spaces remain, even after being compressed.
def keep_spaces(htmls)
  context 'keep spaces in' do
    htmls.each do |html|
      it html do
        html = '<!DOCTYPE html>' + html
        expect(Squoosh.minify_html(html, HTML_OPTIONS)).to eq html
      end
    end
  end
end

def remove_comments(comment_start, htmls)
  context 'remove comments in' do
    htmls.each do |html|
      it html do
        html = '<!DOCTYPE html>' + html
        expect(Squoosh.minify_html(html, COMMENT_OPTIONS))
          .not_to include comment_start
      end
    end
  end
end

describe Squoosh do
  describe '.minify_html' do
    # An html element's start tag may be omitted if the first thing inside the
    # html element is not a comment.
    omit 'html', ['<html></html>',
                  '<html><head></head></html>',
                  '<html> <head></head></html>',
                  '<html><body></body></html>',
                  '<html>Hello!</html>',
                  '<html> Hello!</html>']

    keep 'html', ['<html><!-- --></html>',
                  '<html lang="en"></html>']

    # An html element's end tag may be omitted if the html element is not
    # immediately followed by a comment.
    omit '/html', ['<html></html>']

    keep '/html', ['<html></html><!-- -->']

    # A head element's start tag may be omitted if the element is empty, or if
    # the first thing inside the head element is an element.
    omit 'head', ['<head></head>',
                  '<head><title></title></head>']
    keep 'head',
         ['<head id=X></head>',
          '<head><!-- -->' \
            '<meta http-equiv="Content-Type" content="text/html">' \
            '</head>']

    # A head element's end tag may be omitted if the head element is not
    # immediately followed by a space character or a comment.
    # [There seems to be no way to represent a space after </head> in HTML, it
    # appears in the <body> instead. -- sfc]
    omit '/head', ['<head><title></title></head><body>',
                   '<head><title></title></head><p>',
                   '<head><title></title></head>X']
    keep '/head', ['<head><title></title></head><!-- --><body>']

    # A body element's start tag may be omitted if the element is empty, or if
    # the first thing inside the body element is not a space character or a
    # comment, except if the first thing inside the body element is a meta,
    # link, script, style, or template element.
    omit 'body', ['<body></body>',
                  '<body>',
                  '<body><p>X',
                  '<body>X']
    keep 'body', ['<body> X',
                  '<body><!-- -->',
                  '<body><meta>',
                  '<body><link>',
                  '<body><script></script>',
                  '<body><style></style>',
                  '<body><template></template>',
                  '<body id=X>']

    # A body element's end tag may be omitted if the body element is not
    # immediately followed by a comment.
    omit '/body', ['<html><body></body></html>',
                   '<html><body></body> </html>',
                   '<body></body>']
    keep '/body', ['<html><body></body><!-- --></html>']

    # An li element's end tag may be omitted if the li element is immediately
    # followed by another li element or if there is no more content in the
    # parent element.
    omit '/li', ['<ol><li></li><li></li></ol>',
                 '<ol><li></li> <li></li></ol>',
                 '<ol><li></li><!-- --><li></li></ol>',
                 '<ol><li></li> <!-- --><!-- --> <!-- --><li></li></ol>',
                 '<ol><li></li> </ol>',
                 '<ol><li></li><!-- --></ol>',
                 '<ol><li></li> <!-- --><!-- --> <!-- --></ol>']

    keep '/li', ['<ol><li></li><script></script></ol>']

    # A dt element's end tag may be omitted if the dt element is immediately
    # followed by another dt element or a dd element.
    omit '/dt', ['<dl><dt></dt><dt></dt><dd></dd></dl>',
                 '<dl><dt> </dt><dt></dt><!-- --><dd></dd></dl>']

    keep '/dt', ['<dl><dt></dt><script></script></dl>',
                 '<dl><dt></dt></dl>']

    # A dd element's end tag may be omitted if the dd element is immediately
    # followed by another dd element or a dt element, or if there is no more
    # content in the parent element.
    omit '/dd', ['<dl><dt></dt><dd></dd><dd></dd></dl>',
                 '<dl><dt></dt><dd></dd> <dd></dd></dl>',
                 '<dl><dt></dt><dd></dd><!-- --><dd></dd></dl>',
                 '<dl><dt></dt><dd></dd><dt></dt><dd></dd></dl>',
                 '<dl><dt></dt><dd></dd> <dt></dt><dd></dd></dl>',
                 '<dl><dt></dt><dd></dd><!-- --><dt></dt><dd></dd></dl>',
                 '<dl><dt></dt><dd></dd> </dl>',
                 '<dl><dt></dt><dd></dd><!-- --></dl>']

    keep '/dd', ['<dl><dt></dt><dd></dd><script></script>']

    # A p element's end tag may be omitted if the p element is immediately
    # followed by an address, article, aside, blockquote, div, dl, fieldset,
    # footer, form, h1, h2, h3, h4, h5, h6, header, hgroup, hr, main, nav, ol,
    # p, pre, section, table, or ul, element, or if there is no more content
    # in the parent element and the parent element is not an a element.
    omit '/p', (['<p></p><hr>',
                 '<p></p> <hr>',
                 '<p></p><!-- --><hr>',
                 '<p></p>',
                 '<p></p> ',
                 '<p></p><!-- -->'] +
                %w[address article aside blockquote div dl fieldset footer form
                   h1 h2 h3 h4 h5 h6 header hgroup main nav ol p pre section
                   table ul].flat_map do |t|
                  ["<p></p><#{t}></#{t}>",
                   "<p></p> <#{t}></#{t}>",
                   "<p></p><!-- --><#{t}></#{t}>"]
                end)

    keep '/p', ['<p></p><script></script>',
                '<p></p> <script></script>',
                '<p></p><!-- --><script></script>',
                '<a><p></p></a>',
                '<a><p></p> </a>',
                '<a><p></p><!-- --></a>']

    # An rb element's end tag may be omitted if the rb element is immediately
    # followed by an rb, rt, rtc or rp element, or if there is no more content
    # in the parent element.

    # An rt element's end tag may be omitted if the rt element is immediately
    # followed by an rb, rt, rtc, or rp element, or if there is no more
    # content in the parent element.

    # An rtc element's end tag may be omitted if the rtc element is
    # immediately followed by an rb, rtc or rp element, or if there is no more
    # content in the parent element.

    # An rp element's end tag may be omitted if the rp element is immediately
    # followed by an rb, rt, rtc or rp element, or if there is no more content
    # in the parent element.

    # An optgroup element's end tag may be omitted if the optgroup element is
    # immediately followed by another optgroup element, or if there is no more
    # content in the parent element.

    # An option element's end tag may be omitted if the option element is
    # immediately followed by another option element, or if it is immediately
    # followed by an optgroup element, or if there is no more content in the
    # parent element.

    # A colgroup element's start tag may be omitted if the first thing inside
    # the colgroup element is a col element, and if the element is not
    # immediately preceded by another colgroup element whose end tag has been
    # omitted. (It can't be omitted if the element is empty.)

    # A colgroup element's end tag may be omitted if the colgroup element is
    # not immediately followed by a space character or a comment.

    # A thead element's end tag may be omitted if the thead element is
    # immediately followed by a tbody or tfoot element.
    omit '/thead',
         ['<table><thead></thead><tbody></tbody></table>',
          '<table><thead></thead> <tbody></tbody></table>',
          '<table><thead></thead><!-- --><tbody></tbody></table>',
          '<table><thead></thead><tfoot></tfoot></table>',
          '<table><thead></thead> <tfoot></tfoot></table>',
          '<table><thead></thead><!-- --><tfoot></tfoot></table>']

    keep '/thead',
         ['<table><thead></thead><script></script></thead></table>',
          '<table><thead></thead> <script></script></thead></table>',
          '<table><thead></thead><!-- --><script></script></thead></table>',
          '<table><thead></thead></thead></table>',
          '<table><thead></thead> </thead></table>',
          '<table><thead></thead><!-- --></thead></table>']

    # A tbody element's start tag may be omitted if the first thing inside the
    # tbody element is a tr element, and if the element is not immediately
    # preceded by a tbody, thead, or tfoot element whose end tag has been
    # omitted. (It can't be omitted if the element is empty.)
    omit 'tbody', ['<table><tbody><tr></tr></tbody></table>']

    keep 'tbody',
         ['<table><tbody> <tr></tr></tbody></table>',
          '<table><tbody><!-- --><tr></tr></tbody></table>',
          # '<table><tbody></tbody> <tbody><tr></tr></tbody></table>',
          # '<table><tbody></tbody><!-- --><tbody><tr></tr></tbody></table>',
          '<table><thead></thead> <tbody><tr></tr></tbody></table>',
          '<table><thead></thead><!-- --><tbody><tr></tr></tbody></table>',
          '<table><tfoot></tfoot> <tbody><tr></tr></tbody></table>',
          '<table><tfoot></tfoot><!-- --><tbody><tr></tr></tbody></table>']

    # A tbody element's end tag may be omitted if the tbody element is
    # immediately followed by a tbody or tfoot element, or if there is no more
    # content in the parent element.
    omit '/tbody', ['<table><tbody></tbody><tbody></tbody></table>',
                    '<table><tbody></tbody><tfoot></tfoot></table>',
                    '<table><tbody></tbody></table>',
                    '<table><tbody></tbody> </table>',
                    '<table><tbody></tbody><!-- --></table>']

    keep '/tbody', ['<table><tbody></tbody><script></script></table>']

    # A tfoot element's end tag may be omitted if the tfoot element is
    # immediately followed by a tbody element, or if there is no more content
    # in the parent element.
    omit '/tfoot', ['<table><tfoot></tfoot><tbody></tbody></table>',
                    '<table><tfoot></tfoot> </table>',
                    '<table><tfoot></tfoot><!-- --></table>']

    keep '/tfoot', ['<table><tfoot></tfoot><tfoot></tfoot></table>']

    # A tr element's end tag may be omitted if the tr element is immediately
    # followed by another tr element, or if there is no more content in the
    # parent element.
    omit '/tr', ['<table><tr></tr><tr></tr></table>',
                 '<table><tr></tr> </table>',
                 '<table><tr></tr><!-- --></table>']

    keep '/tr', ['<table><tr></tr><script></script></table>']

    # A td element's end tag may be omitted if the td element is immediately
    # followed by a td or th element, or if there is no more content in the
    # parent element.
    omit '/td', ['<table><tr><td></td><td></td></tr></table>',
                 '<table><tr><td></td><th></th></tr></table>',
                 '<table><tr><td></td> </tr></table>',
                 '<table><tr><td></td><!-- --></tr></table>']

    keep '/td', ['<table><tr><td></td><script></script></table>']

    # A th element's end tag may be omitted if the th element is immediately
    # followed by a td or th element, or if there is no more content in the
    # parent element.
    omit '/th', ['<table><tr><th></th><td></td></tr></table>',
                 '<table><tr><th></th><th></th></tr></table>',
                 '<table><tr><th></th> </tr></table>',
                 '<table><tr><th></th><!-- --></tr></table>']

    keep '/th', ['<table><tr><th></th><script></script></table>']

    # Do not remove spaces between links.
    keep_spaces(['<p><a href=example.com>Foo</a> <a href=example.com>Bar</a>',
                 '<p>Foo <a href=example.com>Bar</a>',
                 '<p><a href=example.com>Foo</a> Bar'])

    context 'remove spaces between elements in' do
      htmls = [['<div> <p> Foo <p> Bar </div>',
                '<div><p>Foo<p>Bar</div>']]
      htmls.each do |html|
        it html[0] do
          input = '<!DOCTYPE html>' + html[0]
          output = '<!DOCTYPE html>' + html[1]
          expect(Squoosh.minify_html(input, HTML_OPTIONS)).to eq output
        end
      end
    end

    # Remove non-loud comments
    remove_comments('<!--',
                    ['<!---->',
                     '<!-- -->',
                     '<body><!-- EOF',
                     '</html><!---->',
                     '</body><!-->',
                     '<!--->',
                     '<!-->'])
    remove_comments('<\?', ['<?php echo "bogus comment"; ?>'])
    remove_comments('</1337', ['</1337 bogus comment>'])

    context 'keep loud comments in' do
      html = '<!-- !LOUD! --><!-- quiet! -->'
      it html do
        expect(Squoosh.minify_html('<!DOCTYPE html>' + html, COMMENT_OPTIONS))
          .to eq '<!DOCTYPE html><!-- !LOUD! -->'
      end
    end

    context 'keep comment-like text in' do
      htmls = [['<title><!-- RCDATA --></title>',
                '<title>&lt;!-- RCDATA --&gt;</title>'],
               ['<script><!-- </script>-->',
                '<script><!-- </script>--&gt;'],
               ['<noframes><!-- RAWTEXT --></noframes>',
                '<noframes><!-- RAWTEXT --></noframes>'],
               ['<script><!-- --></script>',
                '<script><!-- --></script>']]
      htmls.each do |html|
        it html[0] do
          input = '<!DOCTYPE html>' + html[0]
          output = '<!DOCTYPE html>' + html[1]
          expect(Squoosh.minify_html(input, COMMENT_OPTIONS)).to eq output
        end
      end
    end

    context 'combine text nodes in' do
      html = 'foo<!-- -->bar'
      it html do
        expect(Squoosh.minify_html('<!DOCTYPE html>' + html, COMMENT_OPTIONS))
          .to eq '<!DOCTYPE html>foobar'
      end
    end

    context 'combine space nodes in' do
      htmls = [['foo &#x20; bar', 'foo bar'],
               ['foo <!-- --> bar', 'foo bar']]
      htmls.each do |html|
        it html[0] do
          input = '<!DOCTYPE html>' + html[0]
          output = '<!DOCTYPE html>' + html[1]
          expect(Squoosh.minify_html(input, HTML_OPTIONS)).to eq output
        end
      end
    end

    # A single newline may be placed immediately after the start tag of pre
    # and textarea elements. This does not affect the processing of the
    # element. The otherwise optional newline must be included if the
    # element's contents themselves start with a newline (because otherwise
    # the leading newline in the contents would be treated like the optional
    # newline, and ignored).
    context 'keep two newlines at start of' do
      elms = %w[pre textarea]
      elms.each do |elm|
        it elm do
          html = "<!DOCTYPE html><#{elm}>\n\nFoo\n</#{elm}>"
          expect(Squoosh.minify_html(html, HTML_OPTIONS)).to eq html
        end
      end
    end

    context 'remove single newline at start of' do
      elms = %w[pre textarea]
      elms.each do |elm|
        it elm do
          input = "<!DOCTYPE html><#{elm}>\nFoo\n</#{elm}>"
          output = "<!DOCTYPE html><#{elm}>Foo\n</#{elm}>"
          expect(Squoosh.minify_html(input, HTML_OPTIONS)).to eq output
        end
      end
    end

    context 'compress attributes in' do
      htmls = [[%(<a  id="bare"  href='/foo'  ></a>),
                '<a id=bare href=/foo></a>'],
               [%(<p id='"quotes"'>), %(<p id='"quotes"'>)],
               [%(<p id="&quot;x&quot;">), %(<p id='"x"'>)],
               [%(<p id='&apos;x&apos;'>), %(<p id="'x'">)],
               [%(<p id="&quot;x&apos;">), %(<p id="&#34;x'">)],
               ['<p data-model-target="">', '<p data-model-target>']]
      htmls.each do |html|
        it html[0] do
          input = '<!DOCTYPE html>' + html[0]
          output = '<!DOCTYPE html>' + html[1]
          expect(Squoosh.minify_html(input, HTML_OPTIONS)).to eq output
        end
      end
    end

    context 'compress empty, self-closing elements in' do
      htmls = [['<svg></svg>', '<svg/>'],
               ['<svg id="foo"></svg>', '<svg id=foo />'],
               ['<svg id="x y"></svg>', '<svg id="x y"/>'],
               ['<math></math>', '<math/>'],
               ['<math id="foo"></math>', '<math id=foo />'],
               ['<math id="x y"></math>', '<math id="x y"/>']]
      htmls.each do |html|
        it html[0] do
          input = '<!DOCTYPE html>' + html[0]
          output = '<!DOCTYPE html>' + html[1]
          expect(Squoosh.minify_html(input, HTML_OPTIONS)).to eq output
        end
      end
    end

    # Inline styles
    context 'compress style attribute in' do
      html = '<div style="clear:both"></div>'
      it html do
        expect(Squoosh.minify_html('<!DOCTYPE html>' + html, CSS_OPTIONS))
          .to include '<div style=clear:both>'
      end
    end

    # style elements
    context 'compress style elements in' do
      html = "<style>\n#{W3SCHOOLS_CSS}\n</style>"
      it html do
        expect(Squoosh.minify_html('<!DOCTYPE html>' + html, CSS_OPTIONS))
          .to include W3SCHOOLS_CSS_EXPECTED
      end
    end
  end

  describe '.minify_css' do
    context 'minify CSS via sassc' do
      it W3SCHOOLS_CSS do
        expect(Squoosh.minify_css(W3SCHOOLS_CSS, CSS_OPTIONS))
          .to eq W3SCHOOLS_CSS_EXPECTED
      end
    end
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:

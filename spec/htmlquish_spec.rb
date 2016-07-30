require 'spec_helper'

OMIT_TAG_OPTIONS = {
  :omit_tags => true,
  :compress_spaces => false,
  :remove_comments => false,
  :minify_javascript => false,
  :minify_css => false,
}.freeze

def omit(tag, htmls)
  context "omit <#{tag}> in" do
    htmls.each do |html|
      it html do
        expect(HTMLSquish.minify_html('<!DOCTYPE html>' + html,
                                     OMIT_TAG_OPTIONS)).not_to include "<#{tag}"
      end
    end
  end
end

def keep(tag, htmls)
  context "keep <#{tag}> in" do
    htmls.each do |html|
      it html do
        expect(HTMLSquish.minify_html('<!DOCTYPE html>' + html,
                                     OMIT_TAG_OPTIONS)).to include "<#{tag}"
      end
    end
  end
end

describe HTMLSquish do
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
                  '<head><title></title></head>',
                  '<head>  </head>']
    keep 'head', ['<head id=X></head>',
                  '<head><!-- --><meta http-equiv="Content-Type" content="text/html"></head>']

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

    # A dt element's end tag may be omitted if the dt element is immediately
    # followed by another dt element or a dd element.

    # A dd element's end tag may be omitted if the dd element is immediately
    # followed by another dd element or a dt element, or if there is no more
    # content in the parent element.

    # A p element's end tag may be omitted if the p element is immediately
    # followed by an address, article, aside, blockquote, div, dl, fieldset,
    # footer, form, h1, h2, h3, h4, h5, h6, header, hgroup, hr, main, nav, ol,
    # p, pre, section, table, or ul, element, or if there is no more content
    # in the parent element and the parent element is not an a element.

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

    # A tbody element's start tag may be omitted if the first thing inside the
    # tbody element is a tr element, and if the element is not immediately
    # preceded by a tbody, thead, or tfoot element whose end tag has been
    # omitted. (It can't be omitted if the element is empty.)

    # A tbody element's end tag may be omitted if the tbody element is
    # immediately followed by a tbody or tfoot element, or if there is no more
    # content in the parent element.

    # A tfoot element's end tag may be omitted if the tfoot element is
    # immediately followed by a tbody element, or if there is no more content
    # in the parent element.

    # A tr element's end tag may be omitted if the tr element is immediately
    # followed by another tr element, or if there is no more content in the
    # parent element.

    # A td element's end tag may be omitted if the td element is immediately
    # followed by a td or th element, or if there is no more content in the
    # parent element.

    # A th element's end tag may be omitted if the th element is immediately
    # followed by a td or th element, or if there is no more content in the
    # parent element.
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:

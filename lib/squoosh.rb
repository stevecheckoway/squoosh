# frozen_string_literal: true

require 'squoosh/version'
require 'nokogiri'
require 'sassc'
require 'set'
require 'uglifier'

# @author Stephen Checkoway <s@pahtak.org>
# Minify HTML, JavaScript, and CSS.
#
# *Examples*
#
#    html = <<-EOF
#    <!DOCTYPE html>
#    <html>
#      <head>
#        <!-- Set the title -->
#        <title>My fancy title!</title>
#      </head>
#      <body>
#        <p>Two</p>
#        <p>paragraphs.</p>
#      </body>
#    </html>
#    EOF
#    compressed = Squoosh.minify_html(html)
#    # "<!DOCTYPE html><title>My fancy title!</title><p>Two<p>paragraphs."
#
module Squoosh
  # Minify HTML, JavaScript, and CSS using a single set of options. Minified
  # versions of the JavaScript and CSS encountered are cached to speed up
  # minification when the same scripts or inline style sheets appear multiple
  # times.
  class Squoosher
    # Default options for minifying.
    #
    # * ++remove_comments++ Remove all comments that aren't "loud"
    # * ++omit_tags++ Omit unnecessary start and end tags
    # * ++loud_comments++ Keep all comments matching this regex
    # * ++minify_javascript++ Minify JavaScript <tt><script></tt> and inline
    #   JavaScript
    # * ++minify_css++ Minify CSS <tt><style></tt> and inline CSS
    # * ++uglifier_options++ Options to pass to
    #   {https://www.rubydoc.info/gems/uglifier Uglifier}
    # * ++sass_options++ Options to pass to
    #   {https://github.com/sass/sassc-ruby#readme Sassc}
    DEFAULT_OPTIONS = {
      remove_comments: true,
      omit_tags: true,
      compress_spaces: true,
      loud_comments: /\A\s*!/,
      minify_javascript: true,
      minify_css: true,
      uglifier_options: {
        output: {
          ascii_only: false,
          comments: /\A!/
        }
      },
      sass_options: {
        style: :compressed
      }
    }.freeze

    # Create a new instance of ++Squoosher++.
    #
    # @param options [Hash] options to override the default options
    def initialize(options = {})
      options.each do |key, _val|
        unless DEFAULT_OPTIONS.include?(key)
          raise ArgumentError, "Invalid option `#{key}'"
        end
      end
      @options = DEFAULT_OPTIONS.merge(options)
      @js_cache = {}
      @inline_script_cache = {}
      @css_cache = {}
    end

    # Minify HTML and inline JavaScript and CSS.
    #
    # If the ++content++ does not start with an HTML document type
    # <tt><!DOCTYPE html></tt>, then ++content++ is returned unchanged.
    #
    # @param content [String] the HTML to minify
    # @return [String] the minified HTML
    def minify_html(content)
      doc = Nokogiri.HTML5(content)
      return content unless doc&.internal_subset&.html5_dtd?

      remove_comments(doc) if @options[:remove_comments]
      compress_javascript(doc) if @options[:minify_javascript]
      compress_css(doc) if @options[:minify_css]
      doc.children.each { |c| compress_spaces(c) } if @options[:compress_spaces]
      doc.children.map { |node| stringify_node(node) }.join
    end

    # Minify CSS using Sassc.
    #
    # @param content [String] the CSS to minify
    # @return [String] the minified CSS
    def minify_css(content)
      @css_cache[content] ||= begin
        root = SassC::Engine.new(content, @options[:sass_options])
        root.render.rstrip
      end
    end

    # Minify JavaScript using Uglify.
    #
    # @param content [String] the JavaScript to minify
    # @return [String] the minified JavaScript
    def minify_js(content)
      @js_cache[content] ||= uglify(content, @options[:uglifier_options])
    end

    # Element kinds
    VOID_ELEMENTS = Set.new(%w[area base br col embed hr img input
                               keygen link meta param source track wbr]).freeze
    RAW_TEXT_ELEMENTS = Set.new(%w[script style]).freeze
    ESCAPABLE_RAW_TEXT_ELEMENTS = Set.new(%w[textarea title]).freeze
    FOREIGN_ELEMENTS = Set.new(%w[math svg]).freeze
    private_constant :VOID_ELEMENTS, :RAW_TEXT_ELEMENTS
    private_constant :ESCAPABLE_RAW_TEXT_ELEMENTS, :FOREIGN_ELEMENTS

    INLINE_SCRIPT_OPTIONS = {
      output: {
        inline_script: true
      }
    }.freeze
    private_constant :INLINE_SCRIPT_OPTIONS

    private

    def void_element?(node)
      VOID_ELEMENTS.include? node.name
    end

    def raw_text_element?(node)
      RAW_TEXT_ELEMENTS.include? node.name
    end

    def escapable_raw_text_element?(node)
      ESCAPABLE_RAW_TEXT_ELEMENTS.include? node.name
    end

    def foreign_element?(node)
      FOREIGN_ELEMENTS.include? node.name
    end

    def normal_element?(node)
      !void_element?(node) &&
        !raw_text_element?(node) &&
        !escapable_raw_text_element?(node) &&
        !foreign_element?(node)
    end

    HTML_WHITESPACE = "\t\n\f\r "
    private_constant :HTML_WHITESPACE

    def inter_element_whitespace?(node)
      return false unless node.text?

      node.content.each_char.all? { |c| HTML_WHITESPACE.include? c }
    end

    PHRASING_CONTENT = Set.new(%w[a abbr area audio b bdi bdo br button canvas
                                  cite code data datalist del dfn em embed i
                                  iframe img input ins kbd keygen label link
                                  map mark math meta meter noscript object
                                  output picture progress q ruby s samp script
                                  select slot small span strong sub sup svg
                                  template textarea time u var video
                                  wbr]).freeze
    private_constant :PHRASING_CONTENT

    def phrasing_content?(node)
      name = node.name
      PHRASING_CONTENT.include?(name)
    end

    def remove_comments(doc)
      doc.xpath('//comment()').each do |node|
        next if preserve_comment?(node)

        prev_node = node.previous_sibling
        next_node = node.next_sibling
        node.unlink
        if prev_node&.text? && next_node&.text?
          prev_node.content += next_node.content
          next_node.unlink
        end
      end
      nil
    end

    def preserve_comment?(node)
      content = node.content
      return true if content.start_with? '[if '
      return true if /\A\s*!/ =~ content

      # Support other retained comments?
      false
    end

    # rubocop:disable Style/StringConcatenation
    EVENT_HANDLERS_XPATH = (
      # Select all attribute nodes whose names start with "on";
      '//@*[starts-with(name(),"on")]' +
      # and are not descendants of foreign elements
      '[not(ancestor::math or ancestor::svg)]' +
      # and
      '[' +
        # whose names are any of
        %w[abort cancel canplay canplaythrough change click close contextmenu
           cuechange dblclick drag dragend dragenter dragexit dragleave
           dragover dragstart drop durationchange emptied ended input invalid
           keydown keypress keyup loadeddata loadedmetadata loadend loadstart
           mousedown mouseenter mouseleave mousemove mouseout mouseover
           mouseup wheel pause play playing progress ratechange reset seeked
           seeking select show stalled submit suspend timeupdate toggle
           volumechange waiting cut copy paste blur error focus load resize
           scroll].map { |n| "name()=\"on#{n}\"" }.join(' or ') +
        # or whose parent is body or frameset
        ' or (parent::body or parent::frameset)' +
          # and
          ' and (' +
            # whose names are any of
            %w[afterprint beforeprint beforeunload hashchange languagechange
               message offline online pagehide pageshow popstate
               rejectionhandled storage unhandledrejection
               unload].map { |n| "name()=\"on#{n}\"" }.join(' or ') +
          ')' \
          ']'
    ).freeze
    # rubocop:enable Style/StringConcatenation
    private_constant :EVENT_HANDLERS_XPATH

    def uglify(content, options)
      js = Uglifier.compile(content, options)
      js.chomp!(';')
      js
    end

    def compress_script(content)
      @inline_script_cache[content] ||= begin
        options = @options[:uglifier_options].merge(INLINE_SCRIPT_OPTIONS)
        uglify(content, options)
      end
    end

    def compress_javascript(doc)
      # Compress script elements.
      doc.xpath('//script[not(ancestor::math or ancestor::svg)]').each do |node|
        type = node['type']&.downcase
        next unless type.nil? || type == 'text/javascript'

        node.content = compress_script(node.content)
      end
      # Compress event handlers.
      doc.xpath(EVENT_HANDLERS_XPATH).each do |attr|
        attr.content = minify_js(attr.content)
      end
    end

    def compress_css(doc)
      # Compress style elements.
      doc.xpath('//style[not(ancestor::math or ancestor::svg)]').each do |node|
        type = node['type']&.downcase
        next unless type.nil? || type == 'text/css'

        node.content = minify_css node.content
      end
      # Compress style attributes
      doc.xpath('//@style[not(ancestor::math or ancestor::svg)]').each do |node|
        elm_type = node.parent.name
        css = "#{elm_type}{#{node.content}}"
        node.content = minify_css(css)[elm_type.length + 1..-2]
      end
      nil
    end

    def compress_spaces(node)
      if node.text?
        if text_node_removable? node
          node.unlink
        else
          content = node.content
          content.gsub!(/[ \t\n\r\f]+/, ' ')
          content.lstrip! if trim_left? node
          content.rstrip! if trim_right? node
          node.content = content
        end
      elsif node.element? &&
            (node.name == 'pre' || node.name == 'textarea')
        # Leave the contents of these nodes alone.
      elsif normal_element?(node) || node.name == 'title'
        # Compress spaces in normal elements and title.
        node.children.each { |c| compress_spaces c }
      end
      nil
    end

    # Be conservative. If an element can be phrasing content, assume it is.
    def text_node_removable?(node)
      return false unless inter_element_whitespace?(node)
      return false if phrasing_content?(node.parent)

      prev_elm = node.previous_element
      next_elm = node.next_element
      prev_elm.nil? || !phrasing_content?(prev_elm) ||
        next_elm.nil? || !phrasing_content?(next_elm)
    end

    def trim_left?(node)
      prev_elm = node.previous_element
      return !phrasing_content?(node.parent) if prev_elm.nil?

      prev_elm.name == 'br'
    end

    def trim_right?(node)
      next_elm = node.next_element
      return !phrasing_content?(node.parent) if next_elm.nil?

      next_elm.name == 'br'
    end

    def stringify_node(node)
      return node.to_html(encoding: 'UTF-8') unless node.element?

      output = StringIO.new
      # Add start tag. 8.1.2.1
      unless omit_start_tag? node
        output << "<#{node.name}"

        # Add attributes. 8.1.2.3
        last_attr_unquoted = false
        node.attribute_nodes.each do |attr|
          name = qualified_attribute_name(attr)
          last_attr_unquoted = false
          # Make sure there are no character references.
          # XXX: We should be able to compress a bit more by leaving bare & in
          # some cases.
          # value = (attr.value || '')
          # value.gsub!(/&([a-zA-Z0-9]+;|#[0-9]+|#[xX][a-fA-F0-9]+)/, '&amp;\1')
          value = (attr.value || '').gsub('&', '&amp;')
          if value.empty?
            output << " #{name}"
          elsif /[\t\n\f\r "'`=<>]/ !~ value
            last_attr_unquoted = true
            output << " #{name}=#{value}"
          elsif !value.include?('"')
            output << " #{name}=\"#{value}\""
          elsif !value.include?("'")
            output << " #{name}='#{value}'"
          else
            # Contains both ' and ".
            output << " #{name}=\"#{value.gsub('"', '&#34;')}\""
          end
        end

        # Close start tag.
        if self_closing? node
          output << ' ' if last_attr_unquoted
          output << '/'
        end
        output << '>'
      end

      # If pre or textarea start with a newline, double it because the HTML
      # parser strips leading newlines.
      if (node.name == 'pre' || node.name == 'textarea') &&
         !node.children.empty?
        first_child = node.children[0]
        if first_child.text? && first_child.content.start_with?("\n")
          output << "\n"
        end
      end

      # Add content.
      output << node.children.map { |c| stringify_node c }.join

      # Add end tag. 8.1.2.2
      output << "</#{node.name}>" unless omit_end_tag? node
      output.string
    end

    def qualified_attribute_name(attr)
      ns = attr.namespace
      return attr.name if ns.nil?

      uri = ns.href
      if uri == Nokogiri::HTML5::XML_NAMESPACE
        "xml:#{attr.name}"
      elsif uri == Nokogiri::HTML5::XMLNS_NAMESPACE && attr.name == 'xmlns'
        'xmlns'
      elsif uri == Nokogiri::HTML5::XMLNS_NAMESPACE
        "xmlns:#{attr.name}"
      elsif uri == Nokogiri::HTML5::XLINK_NAMESPACE
        "xlink:#{attr.name}"
      else
        # :nocov:
        raise 'Unreachable!'
        # :nocov:
      end
    end

    def self_closing?(node)
      # If we're not omitting end tags, then don't mark foreign elements as
      # self closing.
      return false unless @options[:omit_tags]

      foreign_element?(node) && node.children.empty?
    end

    def content_node?(node)
      # Inter-element whitespace, comment nodes, and processing instruction
      # nodes must be ignored when establishing whether an element's contents
      # match the element's content model or not, and must be ignored when
      # following algorithms that define document and element semantics.
      !(node.comment? ||
        node.processing_instruction? ||
        inter_element_whitespace?(node))
    end

    def previous_sibling_content_node(node)
      while (node = node.previous_sibling)
        return node if content_node?(node)
      end
      nil
    end

    def next_sibling_content_node(node)
      while (node = node.next_sibling)
        return node if content_node?(node)
      end
      nil
    end

    def first_child_content_node(node)
      return nil if node.children.empty?

      node = node.children[0]
      return node if content_node?(node)

      next_sibling_content_node(node)
    end

    def next_sibling_is_nil_or_one_of?(node, elements)
      node = next_sibling_content_node(node)
      node.nil? || (node.element? && elements.include?(node.name))
    end

    def next_sibling_is_one_of?(node, elements)
      node = next_sibling_content_node(node)
      node&.element? && elements.include?(node.name)
    end

    def parent_contains_more_content?(node)
      !next_sibling_content_node(node).nil?
    end

    def omit_start_tag?(node)
      return false unless @options[:omit_tags]
      return false unless node.attributes.empty?

      case node.name
      when 'html'
        # An html element's start tag may be omitted if the first thing inside
        # the html element is not a comment.
        return node.children.empty? || !node.children[0].comment?

      when 'head'
        # A head element's start tag may be omitted if the element is empty,
        # or if the first thing inside the head element is an element.
        return node.children.empty? || node.children[0].element?

      when 'body'
        # A body element's start tag may be omitted if the element is empty,
        # or if the first thing inside the body element is not a space
        # character or a comment, except if the first thing inside the body
        # element is a meta, link, script, style, or template element.
        return true if node.children.empty?

        c = node.children[0]
        return !c.content.start_with?(' ') if c.text?
        return false if c.comment?

        return !c.element? ||
               !%w[meta link script style template].include?(c.name)

      when 'colgroup'
        # A colgroup element's start tag may be omitted if the first thing
        # inside the colgroup element is a col element, and if the element is
        # not immediately preceded by another colgroup element whose end tag
        # has been omitted. (It can't be omitted if the element is empty.)
        child = first_child_content_node(node)
        return false if child.nil? || !child.element? || child.name != 'col'

        prev_node = previous_sibling_content_node(node)
        return !(prev_node&.element? &&
                 prev_node.name == 'colgroup' &&
                 omit_end_tag?(prev_node))

      when 'tbody'
        # A tbody element's start tag may be omitted if the first thing inside
        # the tbody element is a tr element, and if the element is not
        # immediately preceded by a tbody, thead, or tfoot element whose end
        # tag has been omitted. (It can't be omitted if the element is empty.)
        child = first_child_content_node(node)
        return false if child.nil? || !child.element? || child.name != 'tr'

        prev_node = previous_sibling_content_node(node)
        return !(prev_node&.element? &&
                 %w[tbody thead tfoot].include?(prev_node.name) &&
                 omit_end_tag?(prev_node))
      end
      false
    end

    def omit_end_tag?(node)
      return true if void_element?(node) || self_closing?(node)
      return false unless @options[:omit_tags]
      return false if node.parent.name == 'noscript'

      next_node = node.next_sibling
      case node.name
      when 'html'
        # An html element's end tag may be omitted if the html element is not
        # immediately followed by a comment.
        return next_node.nil? || !next_node.comment?

      when 'head'
        # A head element's end tag may be omitted if the head element is not
        # immediately followed by a space character or a comment.
        return next_node.nil? ||
               (next_node.text? && !next_node.content.start_with?(' ')) ||
               !next_node.comment?

      when 'body'
        # A body element's end tag may be omitted if the body element is not
        # immediately followed by a comment.
        return next_node.nil? || !next_node.comment?

      when 'li'
        # An li element's end tag may be omitted if the li element is
        # immediately followed by another li element or if there is no more
        # content in the parent element.
        return next_sibling_is_nil_or_one_of?(node, ['li'])

      when 'dt'
        # A dt element's end tag may be omitted if the dt element is immediately
        # followed by another dt element or a dd element.
        return next_sibling_is_one_of?(node, %w[dt dd])

      when 'dd'
        # A dd element's end tag may be omitted if the dd element is immediately
        # followed by another dd element or a dt element, or if there is no more
        # content in the parent element.
        return next_sibling_is_nil_or_one_of?(node, %w[dt dd])

      when 'p'
        # A p element's end tag can be omitted if the p element is immediately
        # followed by an address, article, aside, blockquote, details, div,
        # dl, fieldset, figcaption, figure, footer, form, h1, h2, h3, h4, h5,
        # h6, header, hgroup, hr, main, menu, nav, ol, p, pre, section, table,
        # or ul element, or if there is no more content in the parent element
        # and the parent element is an HTML element that is not an a, audio,
        # del, ins, map, noscript, or video element, or an autonomous custom
        # element.
        return true if next_sibling_is_one_of?(
          node,
          %w[
            address article aside blockquote details div dl fieldset figcaption
            figure footer form h1 h2 h3 h4 h5 h6 header hgroup hr main menu nav
            ol p pre section table ul
          ]
        )
        return false if foreign_element?(node.parent)

        return !parent_contains_more_content?(node) &&
               !%(a audio del ins map noscript video).include?(node.parent.name)

      when 'rb', 'rt', 'rp'
        # An rb element's end tag may be omitted if the rb element is
        # immediately followed by an rb, rt, rtc or rp element, or if there is
        # no more content in the parent element.
        #
        # An rt element's end tag may be omitted if the rt element is
        # immediately followed by an rb, rt, rtc, or rp element, or if there
        # is no more content in the parent element.
        #
        # An rp element's end tag may be omitted if the rp element is
        # immediately followed by an rb, rt, rtc or rp element, or if there is
        # no more content in the parent element.
        return next_sibling_is_nil_or_one_of?(node, %w[rb rt rtc rp])

      when 'rtc'
        # An rtc element's end tag may be omitted if the rtc element is
        # immediately followed by an rb, rtc or rp element, or if there is no
        # more content in the parent element.
        return next_sibling_is_nil_or_one_of?(node, %w[rb rtc rp])

      when 'optgroup'
        # An optgroup element's end tag may be omitted if the optgroup element
        # is immediately followed by another optgroup element, or if there is
        # no more content in the parent element.
        return next_sibling_is_nil_or_one_of?(node, ['optgroup'])

      when 'option'
        # An option element's end tag may be omitted if the option element is
        # immediately followed by another option element, or if it is
        # immediately followed by an optgroup element, or if there is no more
        # content in the parent element.
        return next_sibling_is_nil_or_one_of?(node, %w[option optgroup])

      when 'colgroup'
        # A colgroup element's end tag may be omitted if the colgroup element is
        # not immediately followed by a space character or a comment.
        return true if next_node.nil?
        return !next_node.content.start_with?(' ') if next_node.text?

        return !next_node.comment?

      when 'thead'
        # A thead element's end tag may be omitted if the thead element is
        # immediately followed by a tbody or tfoot element.
        return next_sibling_is_one_of?(node, %w[tbody tfoot])

      when 'tbody'
        # A tbody element's end tag may be omitted if the tbody element is
        # immediately followed by a tbody or tfoot element, or if there is no
        # more content in the parent element.
        return next_sibling_is_nil_or_one_of?(node, %w[tbody tfoot])

      when 'tfoot'
        # A tfoot element's end tag can be omitted if there is no more content
        # in the parent element.
        return !parent_contains_more_content?(node)

      when 'tr'
        # A tr element's end tag may be omitted if the tr element is immediately
        # followed by another tr element, or if there is no more content in the
        # parent element.
        return next_sibling_is_nil_or_one_of?(node, ['tr'])

      when 'td', 'th'
        # A td element's end tag may be omitted if the td element is immediately
        # followed by a td or th element, or if there is no more content in the
        # parent element.
        #
        # A th element's end tag may be omitted if the th element is immediately
        # followed by a td or th element, or if there is no more content in the
        # parent element.
        return next_sibling_is_nil_or_one_of?(node, %w[td th])
      end
      false
    end
  end

  # Minify HTML convenience method.
  #
  # @param content [String] the HTML to minify
  # @param options [Hash] options to override the ++Squoosher++ default options
  # @return [String] the minified HTML
  def self.minify_html(content, options = {})
    Squoosher.new(options).minify_html content
  end

  # Minify CSS convenience method.
  #
  # @param content [String] the CSS to minify
  # @param options [Hash] options to override the ++Squoosher++ default options
  # @return [String] the minified CSS
  def self.minify_css(content, options = {})
    Squoosher.new(options).minify_css content
  end

  # Minify JavaScript convenience method.
  #
  # @param content [String] the JavaScript to minify
  # @param options [Hash] options to override the ++Squoosher++ default options
  # @return [String] the minified JavaScript
  def self.minify_js(content, options = {})
    Squoosher.new(options).minify_js content
  end
end
# vim: set sw=2 sts=2 ts=8 expandtab:

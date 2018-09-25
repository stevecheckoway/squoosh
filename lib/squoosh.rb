require 'squoosh/version'
require 'nokogumbo'
require 'sass'
require 'set'
require 'uglifier'

module Squoosh
  class Squoosher
    DEFAULT_OPTIONS = {
      :remove_comments => true,
      :omit_tags => true,
      :compress_spaces => true,
      :loud_comments => /\A\s*!/,
      :minify_javascript => true,
      :minify_css => true,
      :uglifier_options => {
        :output => {
          :ascii_only => false,
          :comments => /\A!/,
        },
      },
      :sass_options => {
        :style => :compressed,
      },
    }.freeze
    private_constant :DEFAULT_OPTIONS

    def initialize(options = {})
      options.each do |key, val|
        if !DEFAULT_OPTIONS.include?(key)
          raise ArgumentError.new("Invalid option `#{key}'")
        end
      end
      @options = DEFAULT_OPTIONS.merge(options)
      @js_cache = {}
      @css_cache = {}
    end

    def minify_html(content)
      doc = Nokogiri.HTML5(content)
      return content unless doc&.internal_subset&.html5_dtd?
      remove_comments!(doc) if @options[:remove_comments]
      compress_javascript!(doc) if @options[:minify_javascript]
      compress_css!(doc) if @options[:minify_css]
      doc.children.each { |c| compress_spaces!(c) } if @options[:compress_spaces]
      doc.children.map { |node| stringify_node(node) }.join
    end

    def minify_css(content)
      return content unless @options[:sass_options][:style] == :compressed
      @css_cache[content] ||= begin
        root = Sass::SCSS::CssParser.new(content, nil, nil).parse
        root.options = @options[:sass_options]
        root.render.rstrip
      end
    end

    def minify_js(content)
      @js_cache[content] ||= Uglifier.compile(content, @options[:uglifier_options])
    end

    # Element kinds
    VOID_ELEMENTS = Set.new(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
                     'keygen', 'link', 'meta', 'param', 'source', 'track', 'wbr']).freeze
    RAW_TEXT_ELEMENTS = Set.new(['script', 'style']).freeze
    ESCAPABLE_RAW_TEXT_ELEMENTS = Set.new(['textarea', 'title']).freeze
    FOREIGN_ELEMENTS = Set.new(['math', 'svg']).freeze
    private_constant :VOID_ELEMENTS, :RAW_TEXT_ELEMENTS, :ESCAPABLE_RAW_TEXT_ELEMENTS
    private_constant :FOREIGN_ELEMENTS

    private
    def void_element?(node)
      VOID_ELEMENTS.include? node.name
    end

    private
    def raw_text_element?(node)
      RAW_TEXT_ELEMENTS.include? node.name
    end

    private
    def escapable_raw_text_element?(node)
      ESCAPABLE_RAW_TEXT_ELEMENTS.include? node.name
    end

    private
    def foreign_element?(node)
      FOREIGN_ELEMENTS.include? node.name
    end

    private
    def normal_element?(node)
      !void_element?(node) &&
        !raw_text_element?(node) &&
        !escapable_raw_text_element?(node) &&
        !foreign_element?(node)
    end

    HTML_WHITESPACE = "\t\n\x0c\r "
    private_constant :HTML_WHITESPACE

    private
    def inter_element_whitespace?(node)
      return false unless node.text?
      node.content.each_char.all? { |c| HTML_WHITESPACE.include? c }
    end

    PHRASING_CONTENT = Set.new(%w/a abbr area audio b bdi bdo br button canvas cite
                                  code data datalist del dfn em embed i iframe img
                                  input ins kbd keygen label link map mark math meta
                                  meter noscript object output picture progress q ruby
                                  s samp script select slot small span strong sub sup
                                  svg template textarea time u var video wbr/).freeze
    private_constant :PHRASING_CONTENT

    private
    def phrasing_content?(node)
      name = node.name
      PHRASING_CONTENT.include?(name)
    end

    private
    def remove_comments!(doc)
      doc.xpath("//comment()").each do |node|
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

    private
    def preserve_comment?(node)
      content = node.content
      return true if content.start_with? '[if '
      return true unless /\A\s*!/.match(content).nil?
      # Support other retained comments?
      false
    end

    EVENT_HANDLERS_XPATH = (
      # Select all attribute nodes whose names start with "on";
      '//@*[starts-with(name(),"on")]' +
      # and are not descendants of foreign elements
      '[not(ancestor::math or ancestor::svg)]' +
      # and
      '[' +
        # whose names are any of
        (%w/abort cancel canplay canplaythrough change click close contextmenu
            cuechange dblclick drag dragend dragenter dragexit dragleave
            dragover dragstart drop durationchange emptied ended input invalid
            keydown keypress keyup loadeddata loadedmetadata loadend loadstart
            mousedown mouseenter mouseleave mousemove mouseout mouseover
            mouseup wheel pause play playing progress ratechange reset seeked
            seeking select show stalled submit suspend timeupdate toggle
            volumechange waiting
            cut copy paste
            blur error focus load resize scroll/.map { |n| "name()=\"on#{n}\"" }.join(' or ')) +
        # or whose parent is body or frameset
        ' or (parent::body or parent::frameset)' +
          # and
          ' and (' +
            # whose names are any of
            (%w/afterprint beforeprint beforeunload hashchange languagechange
                message offline online pagehide pageshow popstate
                rejectionhandled storage unhandledrejection
                unload/.map { |n| "name()=\"on#{n}\"" }.join(' or ')) +
          ')' +
      ']'
    ).freeze
    private_constant :EVENT_HANDLERS_XPATH

    private
    def compress_javascript!(doc)
      # Compress script elements.
      doc.xpath("//script[not(ancestor::math or ancestor::svg)]").each do |node|
        type = node['type']&.downcase
        next unless type.nil? || type == "text/javascript"
        node.content = minify_js node.content
      end
      # Compress event handlers.
      doc.xpath(EVENT_HANDLERS_XPATH).each do |attr|
        attr.content = minify_js(attr.content)
      end
    end

    private
    def compress_css!(doc)
      # Compress style elements.
      doc.xpath("//style[not(ancestor::math or ancestor::svg)]").each do |node|
        type = node['type']&.downcase
        next unless type.nil? || type == "text/css"
        node.content = minify_css node.content
      end
      # Compress style attributes
      doc.xpath("//@style[not(ancestor::math or ancestor::svg)]").each do |node|
        elm_type = node.parent.name
        css = "#{elm_type}{#{node.content}}"
        node.content = minify_css(css)[elm_type.length+1 .. -3]
      end
      nil
    end

    private
    def compress_spaces!(node)
      if node.text?
        if text_node_removable? node
          node.unlink
        else
          content = node.content
          content.gsub! /[ \t\n\r\x0c]+/, " "
          content.lstrip! if trim_left? node
          content.rstrip! if trim_right? node
          node.content = content
        end
      elsif node.element?
        # Remove leading newline in pre and textarea tags unless there are two in
        # a row.
        if node.name == 'pre' || node.name == 'textarea'
          if node.children[0]&.text?
            content = node.children[0].content
            node.children[0].content = content if content.sub!(/\A\r\n?([^\r]|\z)/, '\1') ||
                                                  content.sub!(/\A\n([^\n]|\z)/, '\1')
          end
        # Compress spaces in normal elements and title.
        elsif normal_element?(node) || node.name == 'title'
          node.children.each { |c| compress_spaces! c }
        end
      end
      nil
    end

    # Be conservative. If an element can be phrasing content, assume it is.
    private
    def text_node_removable?(node)
      return false unless inter_element_whitespace?(node)
      return false if phrasing_content?(node.parent)
      prev_elm = node.previous_element
      next_elm = node.next_element
      prev_elm.nil? || !phrasing_content?(prev_elm) ||
        next_elm.nil? || !phrasing_content?(next_elm)
    end

    private
    def trim_left?(node)
      prev_elm = node.previous_element
      return !phrasing_content?(node.parent) if prev_elm.nil?
      prev_elm.name == 'br'
    end

    private
    def trim_right?(node)
      next_elm = node.next_element
      return !phrasing_content?(node.parent) if next_elm.nil?
      next_elm.name == 'br'
    end

    private
    def stringify_node(node)
      return node.to_html(:encoding => 'UTF-8') if !node.element?

      output = ''
      # Add start tag. 8.1.2.1
      if !omit_start_tag? node
        output << "<#{node.name}"

        # Add attributes. 8.1.2.3
        last_attr_unquoted = false
        node.attributes.each do |name, attr|
          last_attr_unquoted = false
          # Make sure there are no character references.
          # XXX: We should be able to compress a bit more by leaving bare & in
          # some cases.
          # value = (attr.value || '').gsub /&([a-zA-Z0-9]+;|#[0-9]+|#[xX][a-fA-F0-9]+)/, '&amp;\1'
          value = (attr.value || '').gsub /&/, '&amp;'
          case true
          when value.empty?
            output << ' ' + name
          when ![' ', "\t", "\n", "\x0c", "\r", '"',
                  "'", '=', '<', '>', '`'].any? { |c| value.include? c }
            last_attr_unquoted = true
            output << " #{name}=#{value}"
          when !value.include?('"')
            output << " #{name}=\"#{value}\""
          when !value.include?("'")
            output << " #{name}='#{value}'"
          else
            # Contains both ' and ".
            output << " #{name}=\"#{value.gsub('"', '&#34;')}\""
          end
        end

        # Close start tag.
        if node_is_self_closing? node
          output << ' ' if last_attr_unquoted
          output << '/'
        end
        output << '>'
      end

      # Add content.
      output << node.children.map { |c| stringify_node c }.join

      # Add end tag. 8.1.2.2
      if !omit_end_tag? node
        output << "</#{node.name}>"
      end
      output
    end

    private
    def node_is_self_closing?(node)
      foreign_element?(node) && node.children.empty?
    end

    private
    def omit_start_tag?(node)
      return false unless @options[:omit_tags]
      return false unless node.attributes.empty?
      case node.name
      when 'html'
        # An html element's start tag may be omitted if the first thing inside the
        # html element is not a comment.
        return node.children.empty? || !node.children[0].comment?

      when 'head'
        # A head element's start tag may be omitted if the element is empty, or if
        # the first thing inside the head element is an element.
        return node.children.empty? || node.children[0].element?

      when 'body'
        # A body element's start tag may be omitted if the element is empty, or if
        # the first thing inside the body element is not a space character or a
        # comment, except if the first thing inside the body element is a meta,
        # link, script, style, or template element.
        return true if node.children.empty?
        c = node.children[0]
        return !c.content.start_with?(' ') if c.text?
        return false if c.comment?
        return !c.element? || !['meta', 'link', 'script', 'style', 'template'].include?(c.name)

      when 'colgroup'
        # A colgroup element's start tag may be omitted if the first thing inside
        # the colgroup element is a col element, and if the element is not
        # immediately preceded by another colgroup element whose end tag has been
        # omitted. (It can't be omitted if the element is empty.)
        return false if node.children.empty?
        return false unless node.children[0].name == 'col'
        prev_elm = node.previous_element
        return prev_elm.nil? || prev_elm.name != 'col' || !omit_end_tag?(prev_elm)

      when 'tbody'
        # A tbody element's start tag may be omitted if the first thing inside the
        # tbody element is a tr element, and if the element is not immediately
        # preceded by a tbody, thead, or tfoot element whose end tag has been
        # omitted. (It can't be omitted if the element is empty.)
        return false if node.children.empty?
        return false unless node.children[0].name == 'tr'
        prev_elm = node.previous_element
        return prev_elm.nil? || !['tbody', 'thead', 'tfoot'].include?(prev_elm.name) ||
          !omit_end_tag?(prev_elm)
      end
      false
    end

    private
    def parent_contains_more_content?(node)
      n = node
      while node = node.next_sibling
        next if node.comment?
        next if node.processing_instruction?
        next if inter_element_whitespace? node
        return true
      end
      false
      # !node.xpath("following-sibling::node()").to_a.all? do |node|
      #   node.comment? || node.processing_instruction? ||
      #     inter_element_whitespace?(node)
      # end
    end

    private
    def omit_end_tag?(node)
      return true if void_element? node
      return false unless @options[:omit_tags]
      return false if node.parent.name == 'noscript'
      next_node = node.next_sibling
      next_elm = node.next_element
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
        # An li element's end tag may be omitted if the li element is immediately
        # followed by another li element or if there is no more content in the
        # parent element.
        return next_elm&.name == 'li' || !parent_contains_more_content?(node)

      when 'dt'
        # A dt element's end tag may be omitted if the dt element is immediately
        # followed by another dt element or a dd element.
        return ['dt', 'dd'].include? next_elm&.name

      when 'dd'
        # A dd element's end tag may be omitted if the dd element is immediately
        # followed by another dd element or a dt element, or if there is no more
        # content in the parent element.
        return ['dt', 'dd'].include?(next_elm&.name) ||
               !parent_contains_more_content?(node)

      when 'p'
        # A p element's end tag may be omitted if the p element is immediately
        # followed by an address, article, aside, blockquote, div, dl, fieldset,
        # footer, form, h1, h2, h3, h4, h5, h6, header, hgroup, hr, main, nav, ol,
        # p, pre, section, table, or ul, element, or if there is no more content
        # in the parent element and the parent element is not an a element.
        return true if ['address', 'article', 'aside', 'blockquote', 'div', 'dl',
                        'fieldset', 'footer', 'form', 'h1', 'h2', 'h3', 'h4',
                        'h5', 'h6', 'header', 'hgroup', 'hr', 'main', 'nav', 'ol',
                        'p', 'pre', 'section', 'table', 'ul'].include? next_elm&.name
        return node.parent.name != 'a' && !parent_contains_more_content?(node)

      when 'rb', 'rt', 'rp'
        # An rb element's end tag may be omitted if the rb element is immediately
        # followed by an rb, rt, rtc or rp element, or if there is no more content
        # in the parent element.
        #
        # An rt element's end tag may be omitted if the rt element is immediately
        # followed by an rb, rt, rtc, or rp element, or if there is no more
        # content in the parent element.
        #
        # An rp element's end tag may be omitted if the rp element is immediately
        # followed by an rb, rt, rtc or rp element, or if there is no more content
        # in the parent element.
        return ['rb', 'rt', 'rtc', 'rp'].include?(next_elm&.name) ||
               !parent_contains_more_content?(node)
      when 'rtc'
        # An rtc element's end tag may be omitted if the rtc element is
        # immediately followed by an rb, rtc or rp element, or if there is no more
        # content in the parent element.
        return ['rb', 'rtc', 'rp'].include?(next_elm&.name) ||
               !parent_contains_more_content?(node)

      when 'optgroup'
        # An optgroup element's end tag may be omitted if the optgroup element is
        # immediately followed by another optgroup element, or if there is no more
        # content in the parent element.
        return next_elm&.name == 'optgroup' ||
               !parent_contains_more_content?(node)

      when 'option'
        # An option element's end tag may be omitted if the option element is
        # immediately followed by another option element, or if it is immediately
        # followed by an optgroup element, or if there is no more content in the
        # parent element.
        return ['option', 'optgroup'].include?(next_elm&.name) ||
               !parent_contains_more_content?(node)

      when 'colgroup'
        # A colgroup element's end tag may be omitted if the colgroup element is
        # not immediately followed by a space character or a comment.
        return next_node.nil? ||
               (next_node.text? && !next_node.content.start_with(' ')) ||
               !next_node.comment?

      when 'thead'
        # A thead element's end tag may be omitted if the thead element is
        # immediately followed by a tbody or tfoot element.
        return ['tbody', 'tfoot'].include? next_elm&.name

      when 'tbody'
        # A tbody element's end tag may be omitted if the tbody element is
        # immediately followed by a tbody or tfoot element, or if there is no more
        # content in the parent element.
        return ['tbody', 'tfoot'].include?(next_elm&.name) ||
               !parent_contains_more_content?(node)

      when 'tfoot'
        # A tfoot element's end tag may be omitted if the tfoot element is
        # immediately followed by a tbody element, or if there is no more content
        # in the parent element.
        return next_elm&.name == 'tbody' ||
               !parent_contains_more_content?(node)

      when 'tr'
        # A tr element's end tag may be omitted if the tr element is immediately
        # followed by another tr element, or if there is no more content in the
        # parent element.
        return next_elm&.name == 'tr' ||
               !parent_contains_more_content?(node)

      when 'td', 'th'
        # A td element's end tag may be omitted if the td element is immediately
        # followed by a td or th element, or if there is no more content in the
        # parent element.
        #
        # A th element's end tag may be omitted if the th element is immediately
        # followed by a td or th element, or if there is no more content in the
        # parent element.
        return ['td', 'th'].include?(next_elm&.name) ||
               !parent_contains_more_content?(node)
      end
      false
    end
  end

  module_function
  def minify_html(content, options = {})
    Squoosher.new(options).minify_html content
  end

  module_function
  def minify_css(content, options = {})
    Squoosher.new(options).minify_css content
  end

  module_function
  def minify_js(content, options = {})
    Squoosher.new(options).minify_js content
  end
end
# vim: set sw=2 sts=2 ts=8 expandtab:

require "json"
require "cgi"

module Cms
  module Layout
    ENTITIES = ["BlogPosting", "Person", "Organization", "WebPage", "ImageObject", "VideoObject", "AudioObject", "CategoryCode", "CategoryCodeSet", "DefinedTerm", "DefinedTermSet", "Comment", "WebSite", "SiteNavigationElement"].freeze

    PLURALS = {
      "BlogPosting" => "blog-postings",
      "Person" => "persons",
      "Organization" => "organizations",
      "WebPage" => "web-pages",
      "ImageObject" => "image-objects",
      "VideoObject" => "video-objects",
      "AudioObject" => "audio-objects",
      "CategoryCode" => "category-codes",
      "CategoryCodeSet" => "category-code-sets",
      "DefinedTerm" => "defined-terms",
      "DefinedTermSet" => "defined-term-sets",
      "Comment" => "comments",
      "WebSite" => "web-sites",
      "SiteNavigationElement" => "site-navigation-elements",
    }.freeze

    DISPLAY_KEYS = {
      "BlogPosting" => ["headline", "alternativeHeadline"],
      "Person" => ["name", "givenName", "familyName"],
      "Organization" => ["name", "legalName"],
      "WebPage" => ["headline"],
      "ImageObject" => ["name", "caption", "contentUrl"],
      "VideoObject" => ["name", "caption", "contentUrl"],
      "AudioObject" => ["name", "contentUrl"],
      "CategoryCode" => ["name", "codeValue"],
      "CategoryCodeSet" => ["name"],
      "DefinedTerm" => ["name", "termCode"],
      "DefinedTermSet" => ["name"],
      "Comment" => ["text"],
      "WebSite" => ["name"],
      "SiteNavigationElement" => ["name"],
    }.freeze

    FORM_ISO_PATTERN = %r{\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}\z}

    HTML_ESCAPE = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;", "'" => "&#39;" }.freeze

    def self.plural_of(entity)
      PLURALS[entity] || (entity.downcase + "s")
    end

    def self.escape_html(value)
      return "" if value.nil? || value == ""
      value.to_s.gsub(/[&<>"']/) { |c| HTML_ESCAPE[c] }
    end

    def self.csrf_field(token)
      %(<input type="hidden" name="_csrf" value="#{escape_html(token)}">)
    end

    def self.safe_href?(value)
      return false unless value.is_a?(String)
      v = value.strip.downcase
      v.start_with?("http://", "https://", "mailto:", "/")
    end

    def self.layout(title: "CMS Admin", body: "", current_entity: nil, user: nil, csrf: nil, flash: nil)
      if user
        nav = ENTITIES.map do |e|
          current = e == current_entity ? %( aria-current="page") : ""
          %(<li><a href="/#{PLURALS[e]}"#{current}>#{escape_html(e)}</a></li>)
        end.join
        logout = %(<form method="POST" action="/logout" class="logout">#{csrf_field(csrf)}<button type="submit">Sign out</button></form>)
        header = %(<header>
<nav aria-label="Primary">
<ul>#{nav}</ul>
</nav>
<p class="session">Signed in as <strong>#{escape_html(user["username"])}</strong> (#{escape_html(user["role"])}) #{logout}</p>
</header>)
      else
        header = %(<header><p><strong>CMS Admin</strong></p></header>)
      end
      flash_el = flash ? %(<p role="status">#{escape_html(flash)}</p>) : ""
      %(<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>#{escape_html(title)} — CMS Admin</title>
<link rel="stylesheet" href="/style.css">
</head>
<body>
#{header}
<main>
<h1>#{escape_html(title)}</h1>
#{flash_el}
#{body}
</main>
</body>
</html>
)
    end

    def self.display_name(item, entity)
      return "" if item.nil? || item.empty?
      keys = DISPLAY_KEYS[entity] || ["name", "headline"]
      keys.each do |k|
        v = item[k]
        return v if v.is_a?(String) && !v.empty?
      end
      item["id"] || ""
    end

    def self.error_page(status, message, user = nil)
      {
        "status" => status,
        "html" => layout(title: status == 404 ? "Not Found" : "Error", user: user,
                         body: %(<p role="alert">#{escape_html(message)}</p>)),
      }
    end

    def self.format_scalar(value, use)
      if use == "URL"
        return escape_html(value) unless safe_href?(value)
        v = escape_html(value)
        return %(<a href="#{v}" rel="noopener noreferrer">#{v}</a>)
      end
      if ["DateTime", "Date", "Time"].include?(use)
        v = escape_html(value)
        return %(<time datetime="#{v}">#{v}</time>)
      end
      return (value ? "Yes" : "No") if use == "Boolean"
      escape_html(value.to_s)
    end

    def self.format_value(value, prop)
      return "<em>—</em>" if value.nil? || value == ""
      if value.is_a?(Array)
        return "<em>—</em>" if value.empty?
        single = prop.merge("cardinality" => "one")
        items = value.map { |v| %(<li>#{format_value(v, single)}</li>) }.join
        return %(<ul>#{items}</ul>)
      end
      case prop["kind"]
      when "Ref"
        target = prop["targets"][0]
        plural = PLURALS[target] || (target.downcase + "s")
        return %(<a href="/#{plural}/#{escape_html(value)}">#{escape_html(target)}: #{escape_html(value)}</a>)
      when "Embed"
        if prop["use"] == "Language" && value.is_a?(Hash)
          code = value["alternateName"] || value["name"] || ""
          return %(<span lang="#{escape_html(code)}">#{escape_html(code)}</span>)
        end
        return %(<code>#{escape_html(JSON.generate(value))}</code>)
      when "Enum"
        return escape_html(value.to_s)
      end
      format_scalar(value, prop["use"])
    end

    def self.render_field(prop, value: nil, ref_options: nil, errors: nil)
      ref_options ||= {}
      errors ||= []
      field_id = "field-#{prop["name"]}"
      required_attr = prop["required"] ? " required" : ""
      required_mark = prop["required"] ? %( <span aria-hidden="true">*</span>) : ""
      aria_invalid = errors.empty? ? "" : %( aria-invalid="true")
      label_text = escape_html(prop["name"]) + required_mark
      help_html = errors.empty? ? "" : %(<small role="alert">#{errors.map { |e| escape_html(e) }.join("; ")}</small>)
      input_html = render_input(prop, value, field_id, required_attr, aria_invalid, ref_options)
      %(<p>
<label for="#{field_id}">#{label_text}</label><br>
#{input_html}
#{help_html}
</p>)
    end

    def self.render_input(prop, value, field_id, required_attr, aria_invalid, ref_options)
      name = escape_html(prop["name"])
      kind = prop["kind"]
      max_length_attr = prop["maxLength"].nil? ? "" : %( maxlength="#{prop["maxLength"]}")
      if kind == "Enum"
        opts = prop["values"].map { |v| %(<option value="#{escape_html(v)}"#{v == value ? " selected" : ""}>#{escape_html(v)}</option>) }.join
        placeholder = prop["required"] ? "" : %(<option value="">—</option>)
        return %(<select id="#{field_id}" name="#{name}"#{required_attr}#{aria_invalid}>#{placeholder}#{opts}</select>)
      end
      if kind == "Ref"
        current = if prop["cardinality"] == "many"
                    value.is_a?(Array) ? value : (value ? [value] : [])
                  else
                    value.is_a?(Array) ? value[0] : value
                  end
        opts = (ref_options[prop["name"]] || []).map do |o|
          sel = prop["cardinality"] == "many" ? current.include?(o["value"]) : current == o["value"]
          %(<option value="#{escape_html(o["value"])}"#{sel ? " selected" : ""}>#{escape_html(o["label"])}</option>)
        end.join
        multiple = prop["cardinality"] == "many" ? " multiple" : ""
        placeholder = (prop["cardinality"] == "one" && !prop["required"]) ? %(<option value="">—</option>) : ""
        return %(<select id="#{field_id}" name="#{name}"#{multiple}#{required_attr}#{aria_invalid}>#{placeholder}#{opts}</select>)
      end
      if kind == "Embed" && prop["use"] == "Language"
        v = value.is_a?(Hash) ? (value["alternateName"] || "") : (value || "")
        return %(<input id="#{field_id}" name="#{name}" type="text" value="#{escape_html(v)}"#{required_attr}#{aria_invalid}>)
      end
      if prop["cardinality"] == "many"
        v = value.is_a?(Array) ? value.join("\n") : (value || "")
        return %(<textarea id="#{field_id}" name="#{name}" rows="3"#{required_attr}#{aria_invalid}>#{escape_html(v)}</textarea>)
      end
      use = prop["use"]
      if use == "Text" && prop["multiline"]
        return %(<textarea id="#{field_id}" name="#{name}" rows="6"#{max_length_attr}#{required_attr}#{aria_invalid}>#{escape_html(value)}</textarea>)
      end
      if use == "URL"
        return %(<input id="#{field_id}" name="#{name}" type="url" value="#{escape_html(value)}"#{max_length_attr}#{required_attr}#{aria_invalid}>)
      end
      if use == "Integer"
        v = value.nil? ? "" : escape_html(value.to_s)
        return %(<input id="#{field_id}" name="#{name}" type="number" step="1" value="#{v}"#{required_attr}#{aria_invalid}>)
      end
      if use == "Number"
        v = value.nil? ? "" : escape_html(value.to_s)
        return %(<input id="#{field_id}" name="#{name}" type="number" step="any" value="#{v}"#{required_attr}#{aria_invalid}>)
      end
      if use == "Boolean"
        checked = [true, "true", "on"].include?(value) ? " checked" : ""
        return %(<input id="#{field_id}" name="#{name}" type="checkbox" value="true"#{checked}#{aria_invalid}>)
      end
      if ["DateTime", "Date", "Time"].include?(use)
        v = value.is_a?(String) ? value.sub(/Z\z/, "")[0, 16] : ""
        return %(<input id="#{field_id}" name="#{name}" type="datetime-local" value="#{escape_html(v)}"#{required_attr}#{aria_invalid}>)
      end
      %(<input id="#{field_id}" name="#{name}" type="text" value="#{escape_html(value)}"#{max_length_attr}#{required_attr}#{aria_invalid}>)
    end

    def self.coerce_form_value(raw, prop)
      return nil if raw.nil? || raw == ""
      return raw.to_s if ["Enum", "Ref"].include?(prop["kind"])
      return { "@type" => "Language", "alternateName" => raw.to_s } if prop["kind"] == "Embed" && prop["use"] == "Language"
      use = prop["use"]
      if use == "Integer"
        begin
          return Integer(raw, 10)
        rescue ArgumentError, TypeError
          return raw
        end
      end
      if use == "Number"
        begin
          return Float(raw)
        rescue ArgumentError, TypeError
          return raw
        end
      end
      return ["true", "on", "1"].include?(raw) if use == "Boolean"
      if ["DateTime", "Date", "Time"].include?(use)
        return raw + ":00Z" if raw.is_a?(String) && FORM_ISO_PATTERN.match?(raw)
        return raw.to_s
      end
      raw.to_s
    end

    def self.parse_form_pairs(raw)
      return {} if raw.nil? || raw.empty?
      out = {}
      raw.split("&").each do |pair|
        next if pair.empty?
        k, _, v = pair.partition("=")
        key = CGI.unescape(k)
        value = CGI.unescape(v)
        if out.key?(key)
          out[key] = [out[key]] unless out[key].is_a?(Array)
          out[key] << value
        else
          out[key] = value
        end
      end
      out
    end

    def self.parse_form_body(raw, properties)
      pairs = parse_form_pairs(raw)
      out = {}
      properties.each do |prop|
        name = prop["name"]
        if prop["cardinality"] == "many"
          if prop["kind"] == "Ref"
            values = pairs[name]
            values = values.nil? ? [] : (values.is_a?(Array) ? values : [values])
            values = values.reject { |v| v == "" }
          else
            single = pairs[name] || ""
            single = single.join("\n") if single.is_a?(Array)
            values = single.split(/\r?\n/).map(&:strip).reject(&:empty?)
          end
          coerced = values.map { |v| coerce_form_value(v, prop) }.reject(&:nil?)
          out[name] = coerced unless coerced.empty?
        elsif prop["kind"] == "InlineScalar" && prop["use"] == "Boolean"
          out[name] = pairs.key?(name)
        else
          v = coerce_form_value(pairs[name], prop)
          out[name] = v unless v.nil?
        end
      end
      out
    end

    def self.form_values_from_item(item, properties)
      out = {}
      return out if item.nil?
      properties.each do |p|
        out[p["name"]] = item[p["name"]] if item.key?(p["name"])
      end
      out
    end
  end
end

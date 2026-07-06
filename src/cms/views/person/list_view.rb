require "uri"
require "cgi"

require_relative "../../layout"

module Cms
  module Views
    module Person
      module ListView
        ENTITY = "Person"
        BASE = "/persons"
        PROPERTIES = [
        { "name" => "name", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 256, "cardinality" => "one", "required" => true },
        { "name" => "givenName", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 256, "cardinality" => "one", "required" => false },
        { "name" => "familyName", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 256, "cardinality" => "one", "required" => false },
        { "name" => "alternateName", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 256, "cardinality" => "one", "required" => false },
        { "name" => "email", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 320, "cardinality" => "one", "required" => false },
        { "name" => "url", "kind" => "InlineScalar", "use" => "URL", "maxLength" => 2048, "cardinality" => "one", "required" => false },
        { "name" => "description", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 5000, "multiline" => true, "cardinality" => "one", "required" => false },
        { "name" => "image", "kind" => "Ref", "targets" => ["ImageObject"], "cardinality" => "one", "required" => false },
        { "name" => "worksFor", "kind" => "Ref", "targets" => ["Organization"], "cardinality" => "one", "required" => false },
        { "name" => "jobTitle", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 256, "cardinality" => "one", "required" => false },
        { "name" => "sameAs", "kind" => "InlineScalar", "use" => "URL", "maxLength" => 2048, "cardinality" => "many", "required" => false },
      ].freeze
        EXTRA_COLS = ["url"].freeze

        def self.page_int(raw, default, minimum)
          value = Integer(raw, 10)
          value >= minimum ? value : minimum
        rescue ArgumentError, TypeError
          default
        end

        def self.page_href(parsed, next_offset)
          params = {}
          parsed.each { |k, v| params[k] = v.dup }
          params["offset"] = [next_offset.to_s]
          qs = params.map { |k, vs| vs.map { |v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join("&") }.join("&")
          "#{BASE}?#{qs}"
        end

        def self.render(opts)
          api = opts["api"]
          user = opts["user"]
          csrf = opts["csrf"]
          parsed = CGI.parse(URI(opts["url"] || BASE).query || "")
          query = {}
          ["limit", "offset", "sort", "order"].each { |k| query[k] = parsed[k][0] if parsed.key?(k) && !parsed[k].empty? }
          r = api.list(ENTITY, query)
          unless r["status"] == 200
            msg = r["body"].is_a?(Hash) ? (r["body"]["message"] || "unknown error") : "unknown error"
            return { "status" => r["status"], "html" => Cms::Layout.layout(title: ENTITY + "s", current_entity: ENTITY, user: user, csrf: csrf, body: %(<p role="alert">Failed to load: #{Cms::Layout.escape_html(msg)}</p>)) }
          end
          headers = (["Name", "Created"] + EXTRA_COLS + ["Actions"]).map { |h| %(<th scope="col">#{Cms::Layout.escape_html(h)}</th>) }.join
          prop_by_name = {}
          PROPERTIES.each { |p| prop_by_name[p["name"]] = p }
          rows = r["body"]["items"].map do |item|
            extras = EXTRA_COLS.map do |c|
              cell = prop_by_name.key?(c) ? Cms::Layout.format_value(item[c], prop_by_name[c]) : Cms::Layout.escape_html(item[c].to_s)
              %(<td>#{cell}</td>)
            end.join
            id_e = Cms::Layout.escape_html(item["id"])
            name_cell = Cms::Layout.escape_html(Cms::Layout.display_name(item, ENTITY))
            created = Cms::Layout.escape_html(item["dateCreated"])
            %(<tr>
<td><a href="#{BASE}/#{id_e}">#{name_cell}</a></td>
<td><time datetime="#{created}">#{created}</time></td>
#{extras}
<td><a href="#{BASE}/#{id_e}/edit">Edit</a> · <a href="#{BASE}/#{id_e}/delete">Delete</a></td>
</tr>)
          end
          if rows.empty?
            cols = 3 + EXTRA_COLS.length
            body_rows = %(<tr><td colspan="#{cols}"><em>No items.</em></td></tr>)
          else
            body_rows = rows.join
          end
          limit = page_int(parsed.key?("limit") ? parsed["limit"][0] : "20", 20, 1)
          offset = page_int(parsed.key?("offset") ? parsed["offset"][0] : "0", 0, 0)
          prev_link = offset > 0 ? %(<a href="#{Cms::Layout.escape_html(page_href(parsed, [0, offset - limit].max))}" rel="prev">Previous</a>) : ""
          next_link = (offset + limit < r["body"]["total"]) ? %(<a href="#{Cms::Layout.escape_html(page_href(parsed, offset + limit))}" rel="next">Next</a>) : ""
          pagination = (prev_link.empty? && next_link.empty?) ? "" : %(<nav aria-label="Pagination">#{prev_link}#{next_link}</nav>)
          body = %(<p><a href="#{BASE}/new">New #{Cms::Layout.escape_html(ENTITY)}</a></p>
<p>Showing #{r["body"]["items"].length} of #{r["body"]["total"]}.</p>
<table>
<caption>#{Cms::Layout.escape_html(ENTITY)} list</caption>
<thead><tr>#{headers}</tr></thead>
<tbody>#{body_rows}</tbody>
</table>
#{pagination})
          { "status" => 200, "html" => Cms::Layout.layout(title: ENTITY + "s", current_entity: ENTITY, user: user, csrf: csrf, body: body) }
        end
      end
    end
  end
end

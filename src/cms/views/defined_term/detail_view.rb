require_relative "../../layout"

module Cms
  module Views
    module DefinedTerm
      module DetailView
        ENTITY = "DefinedTerm"
        BASE = "/defined-terms"
        PROPERTIES = [
        { "name" => "name", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 256, "cardinality" => "one", "required" => true },
        { "name" => "description", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 5000, "multiline" => true, "cardinality" => "one", "required" => false },
        { "name" => "termCode", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 128, "cardinality" => "one", "required" => true },
        { "name" => "url", "kind" => "InlineScalar", "use" => "URL", "maxLength" => 2048, "cardinality" => "one", "required" => false },
        { "name" => "inDefinedTermSet", "kind" => "Ref", "targets" => ["DefinedTermSet"], "cardinality" => "one", "required" => true },
      ].freeze

        def self.render(opts)
          api = opts["api"]
          user = opts["user"]
          csrf = opts["csrf"]
          r = api.get(ENTITY, opts["id"])
          return Cms::Layout.error_page(404, ENTITY + " not found.", user) if r["status"] == 404
          unless r["status"] == 200
            msg = r["body"].is_a?(Hash) ? (r["body"]["message"] || "Failed to load.") : "Failed to load."
            return Cms::Layout.error_page(r["status"], msg, user)
          end
          item = r["body"]
          rows = PROPERTIES.map { |p| %(<dt>#{Cms::Layout.escape_html(p["name"])}</dt><dd>#{Cms::Layout.format_value(item[p["name"]], p)}</dd>) }.join
          id_e = Cms::Layout.escape_html(item["id"])
          created = Cms::Layout.escape_html(item["dateCreated"])
          modified = Cms::Layout.escape_html(item["dateModified"])
          meta = %(<dt>id</dt><dd><code>#{id_e}</code></dd><dt>dateCreated</dt><dd><time datetime="#{created}">#{created}</time></dd><dt>dateModified</dt><dd><time datetime="#{modified}">#{modified}</time></dd>)
          body = %(<article>
<dl>#{rows}#{meta}</dl>
<p>
<a href="#{BASE}/#{id_e}/edit">Edit</a> ·
<a href="#{BASE}/#{id_e}/delete">Delete</a> ·
<a href="#{BASE}">Back to list</a>
</p>
</article>)
          { "status" => 200, "html" => Cms::Layout.layout(title: Cms::Layout.display_name(item, ENTITY), current_entity: ENTITY, user: user, csrf: csrf, body: body) }
        end
      end
    end
  end
end

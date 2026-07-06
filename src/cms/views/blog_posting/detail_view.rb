require_relative "../../layout"

module Cms
  module Views
    module BlogPosting
      module DetailView
        ENTITY = "BlogPosting"
        BASE = "/blog-postings"
        PROPERTIES = [
        { "name" => "headline", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 256, "cardinality" => "one", "required" => true },
        { "name" => "alternativeHeadline", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 256, "cardinality" => "one", "required" => false },
        { "name" => "description", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 5000, "multiline" => true, "cardinality" => "one", "required" => false },
        { "name" => "articleBody", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 65536, "multiline" => true, "cardinality" => "one", "required" => true },
        { "name" => "author", "kind" => "Ref", "targets" => ["Person"], "cardinality" => "one", "required" => true },
        { "name" => "publisher", "kind" => "Ref", "targets" => ["Organization"], "cardinality" => "one", "required" => false },
        { "name" => "image", "kind" => "Ref", "targets" => ["ImageObject"], "cardinality" => "many", "required" => false },
        { "name" => "video", "kind" => "Ref", "targets" => ["VideoObject"], "cardinality" => "many", "required" => false },
        { "name" => "audio", "kind" => "Ref", "targets" => ["AudioObject"], "cardinality" => "many", "required" => false },
        { "name" => "keywords", "kind" => "Ref", "targets" => ["DefinedTerm"], "cardinality" => "many", "required" => false },
        { "name" => "about", "kind" => "Ref", "targets" => ["CategoryCode"], "cardinality" => "many", "required" => false },
        { "name" => "datePublished", "kind" => "InlineScalar", "use" => "DateTime", "cardinality" => "one", "required" => false },
        { "name" => "dateModified", "kind" => "InlineScalar", "use" => "DateTime", "cardinality" => "one", "required" => false },
        { "name" => "dateCreated", "kind" => "InlineScalar", "use" => "DateTime", "cardinality" => "one", "required" => false },
        { "name" => "url", "kind" => "InlineScalar", "use" => "URL", "maxLength" => 2048, "cardinality" => "one", "required" => true },
        { "name" => "inLanguage", "kind" => "Embed", "use" => "Language", "cardinality" => "one", "required" => false },
        { "name" => "isAccessibleForFree", "kind" => "InlineScalar", "use" => "Boolean", "cardinality" => "one", "required" => false },
        { "name" => "wordCount", "kind" => "InlineScalar", "use" => "Integer", "cardinality" => "one", "required" => false },
        { "name" => "creativeWorkStatus", "kind" => "Enum", "values" => ["Draft", "Pending", "Published", "Archived"], "cardinality" => "one", "required" => false },
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

require_relative "../../layout"

module Cms
  module Views
    module BlogPosting
      module EditView
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

        def self.load_ref_options(api)
          out = {}
          PROPERTIES.each do |prop|
            next unless prop["kind"] == "Ref"
            collected = []
            prop["targets"].each do |target|
              r = api.list(target, { "limit" => 100 })
              next unless r["status"] == 200 && r["body"].is_a?(Hash)
              (r["body"]["items"] || []).each do |item|
                collected << { "value" => item["id"], "label" => "#{target}: #{Cms::Layout.display_name(item, target)}" }
              end
            end
            out[prop["name"]] = collected
          end
          out
        end

        def self.extract_error_list(body)
          return ["Request failed."] unless body
          if body.is_a?(Hash)
            details = body["details"]
            return details if details.is_a?(Array) && !details.empty?
            message = body["message"]
            return [message] if message.is_a?(String)
          end
          ["Request failed."]
        end

        def self.render_form(opts)
          api = opts["api"]
          user = opts["user"]
          csrf = opts["csrf"]
          item_id = opts["id"]
          values = opts["values"]
          errors = opts["errors"] || []
          field_errors = opts["field_errors"] || {}
          if values.nil?
            r = api.get(ENTITY, item_id)
            return Cms::Layout.error_page(404, ENTITY + " not found.", user) if r["status"] == 404
            unless r["status"] == 200
              msg = r["body"].is_a?(Hash) ? (r["body"]["message"] || "Failed to load.") : "Failed to load."
              return Cms::Layout.error_page(r["status"], msg, user)
            end
            values = Cms::Layout.form_values_from_item(r["body"], PROPERTIES)
          end
          ref_options = load_ref_options(api)
          fields = PROPERTIES.map { |p| Cms::Layout.render_field(p, value: values[p["name"]], ref_options: ref_options, errors: field_errors[p["name"]] || []) }.join("\n")
          error_block = ""
          unless errors.empty?
            items = errors.map { |e| %(<li>#{Cms::Layout.escape_html(e)}</li>) }.join
            error_block = %(<div role="alert"><p>Could not save:</p><ul>#{items}</ul></div>)
          end
          id_e = Cms::Layout.escape_html(item_id)
          body = %(#{error_block}
<form method="POST" action="#{BASE}/#{id_e}/edit">
#{Cms::Layout.csrf_field(csrf)}
#{fields}
<p><button type="submit">Save</button> · <a href="#{BASE}/#{id_e}">Cancel</a></p>
</form>)
          { "status" => errors.empty? ? 200 : 400, "html" => Cms::Layout.layout(title: "Edit " + ENTITY, current_entity: ENTITY, user: user, csrf: csrf, body: body) }
        end

        def self.handle_submit(opts)
          api = opts["api"]
          user = opts["user"]
          item_id = opts["id"]
          payload = Cms::Layout.parse_form_body(opts["form"] || "", PROPERTIES)
          r = api.update(ENTITY, item_id, payload)
          return { "status" => 303, "redirect" => BASE + "/" + item_id } if r["status"] == 200
          return Cms::Layout.error_page(404, ENTITY + " not found.", user) if r["status"] == 404
          { "status" => 400, "errors" => extract_error_list(r["body"]), "values" => payload }
        end
      end
    end
  end
end

require_relative "../../layout"

module Cms
  module Views
    module Comment
      module CreateView
        ENTITY = "Comment"
        BASE = "/comments"
        PROPERTIES = [
        { "name" => "text", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 10000, "multiline" => true, "cardinality" => "one", "required" => true },
        { "name" => "author", "kind" => "Ref", "targets" => ["Person"], "cardinality" => "one", "required" => true },
        { "name" => "about", "kind" => "Ref", "targets" => ["BlogPosting"], "cardinality" => "one", "required" => true },
        { "name" => "parentItem", "kind" => "Ref", "targets" => ["Comment"], "cardinality" => "one", "required" => false },
        { "name" => "dateCreated", "kind" => "InlineScalar", "use" => "DateTime", "cardinality" => "one", "required" => false },
        { "name" => "dateModified", "kind" => "InlineScalar", "use" => "DateTime", "cardinality" => "one", "required" => false },
        { "name" => "upvoteCount", "kind" => "InlineScalar", "use" => "Integer", "cardinality" => "one", "required" => false },
        { "name" => "downvoteCount", "kind" => "InlineScalar", "use" => "Integer", "cardinality" => "one", "required" => false },
        { "name" => "creativeWorkStatus", "kind" => "Enum", "values" => ["Pending", "Approved", "Spam", "Trash"], "cardinality" => "one", "required" => false },
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
          values = opts["values"] || {}
          errors = opts["errors"] || []
          field_errors = opts["field_errors"] || {}
          ref_options = load_ref_options(api)
          fields = PROPERTIES.map { |p| Cms::Layout.render_field(p, value: values[p["name"]], ref_options: ref_options, errors: field_errors[p["name"]] || []) }.join("\n")
          error_block = ""
          unless errors.empty?
            items = errors.map { |e| %(<li>#{Cms::Layout.escape_html(e)}</li>) }.join
            error_block = %(<div role="alert"><p>Could not save:</p><ul>#{items}</ul></div>)
          end
          body = %(#{error_block}
<form method="POST" action="#{BASE}/new">
#{Cms::Layout.csrf_field(csrf)}
#{fields}
<p><button type="submit">Create</button> · <a href="#{BASE}">Cancel</a></p>
</form>)
          { "status" => errors.empty? ? 200 : 400, "html" => Cms::Layout.layout(title: "New " + ENTITY, current_entity: ENTITY, user: user, csrf: csrf, body: body) }
        end

        def self.handle_submit(opts)
          api = opts["api"]
          payload = Cms::Layout.parse_form_body(opts["form"] || "", PROPERTIES)
          r = api.create(ENTITY, payload)
          if r["status"] == 201 && r["body"].is_a?(Hash) && r["body"]["id"]
            return { "status" => 303, "redirect" => BASE + "/" + r["body"]["id"] }
          end
          { "status" => 400, "errors" => extract_error_list(r["body"]), "values" => payload }
        end
      end
    end
  end
end

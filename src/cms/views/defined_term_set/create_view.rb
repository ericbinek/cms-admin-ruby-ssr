require_relative "../../layout"

module Cms
  module Views
    module DefinedTermSet
      module CreateView
        ENTITY = "DefinedTermSet"
        BASE = "/defined-term-sets"
        PROPERTIES = [
        { "name" => "name", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 256, "cardinality" => "one", "required" => true },
        { "name" => "description", "kind" => "InlineScalar", "use" => "Text", "maxLength" => 5000, "multiline" => true, "cardinality" => "one", "required" => false },
        { "name" => "url", "kind" => "InlineScalar", "use" => "URL", "maxLength" => 2048, "cardinality" => "one", "required" => false },
      ].freeze

        def self.load_ref_options(_api)
          {}
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

require_relative "../../layout"

module Cms
  module Views
    module BlogPosting
      module DeleteView
        ENTITY = "BlogPosting"
        BASE = "/blog-postings"

        def self.render_form(opts)
          api = opts["api"]
          user = opts["user"]
          csrf = opts["csrf"]
          item_id = opts["id"]
          r = api.get(ENTITY, item_id)
          return Cms::Layout.error_page(404, ENTITY + " not found.", user) if r["status"] == 404
          unless r["status"] == 200
            msg = r["body"].is_a?(Hash) ? (r["body"]["message"] || "Failed to load.") : "Failed to load."
            return Cms::Layout.error_page(r["status"], msg, user)
          end
          id_e = Cms::Layout.escape_html(item_id)
          body = %(<form method="POST" action="#{BASE}/#{id_e}/delete">
#{Cms::Layout.csrf_field(csrf)}
<p>Delete <strong>#{Cms::Layout.escape_html(Cms::Layout.display_name(r["body"], ENTITY))}</strong>? This cannot be undone.</p>
<p><button type="submit">Confirm Delete</button> · <a href="#{BASE}/#{id_e}">Cancel</a></p>
</form>)
          { "status" => 200, "html" => Cms::Layout.layout(title: "Delete " + ENTITY, current_entity: ENTITY, user: user, csrf: csrf, body: body) }
        end

        def self.handle_submit(opts)
          api = opts["api"]
          user = opts["user"]
          r = api.remove(ENTITY, opts["id"])
          return { "status" => 303, "redirect" => BASE } if [204, 404].include?(r["status"])
          Cms::Layout.error_page(r["status"], "Delete failed.", user)
        end
      end
    end
  end
end

require_relative "layout"

module Cms
  module Login
    def self.render_login(csrf: nil, error: nil, username: "")
      error_block = error ? %(<div role="alert"><p>#{Cms::Layout.escape_html(error)}</p></div>) : ""
      body = %(#{error_block}
<form method="POST" action="/login">
#{Cms::Layout.csrf_field(csrf)}
<p>
<label for="field-username">Username</label><br>
<input id="field-username" name="username" type="text" value="#{Cms::Layout.escape_html(username)}" required autocomplete="username">
</p>
<p>
<label for="field-password">Password</label><br>
<input id="field-password" name="password" type="password" required autocomplete="current-password">
</p>
<p><button type="submit">Sign in</button></p>
</form>)
      { "status" => error ? 401 : 200, "html" => Cms::Layout.layout(title: "Sign in", body: body) }
    end
  end
end

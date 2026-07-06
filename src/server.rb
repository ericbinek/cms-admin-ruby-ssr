require "socket"

require_relative "cms/layout"
require_relative "cms/login"
require_relative "cms/auth"
require_relative "cms/api_client"
require_relative "cms/views/blog_posting/list_view"
require_relative "cms/views/blog_posting/detail_view"
require_relative "cms/views/blog_posting/create_view"
require_relative "cms/views/blog_posting/edit_view"
require_relative "cms/views/blog_posting/delete_view"
require_relative "cms/views/person/list_view"
require_relative "cms/views/person/detail_view"
require_relative "cms/views/person/create_view"
require_relative "cms/views/person/edit_view"
require_relative "cms/views/person/delete_view"
require_relative "cms/views/organization/list_view"
require_relative "cms/views/organization/detail_view"
require_relative "cms/views/organization/create_view"
require_relative "cms/views/organization/edit_view"
require_relative "cms/views/organization/delete_view"
require_relative "cms/views/web_page/list_view"
require_relative "cms/views/web_page/detail_view"
require_relative "cms/views/web_page/create_view"
require_relative "cms/views/web_page/edit_view"
require_relative "cms/views/web_page/delete_view"
require_relative "cms/views/image_object/list_view"
require_relative "cms/views/image_object/detail_view"
require_relative "cms/views/image_object/create_view"
require_relative "cms/views/image_object/edit_view"
require_relative "cms/views/image_object/delete_view"
require_relative "cms/views/video_object/list_view"
require_relative "cms/views/video_object/detail_view"
require_relative "cms/views/video_object/create_view"
require_relative "cms/views/video_object/edit_view"
require_relative "cms/views/video_object/delete_view"
require_relative "cms/views/audio_object/list_view"
require_relative "cms/views/audio_object/detail_view"
require_relative "cms/views/audio_object/create_view"
require_relative "cms/views/audio_object/edit_view"
require_relative "cms/views/audio_object/delete_view"
require_relative "cms/views/category_code/list_view"
require_relative "cms/views/category_code/detail_view"
require_relative "cms/views/category_code/create_view"
require_relative "cms/views/category_code/edit_view"
require_relative "cms/views/category_code/delete_view"
require_relative "cms/views/category_code_set/list_view"
require_relative "cms/views/category_code_set/detail_view"
require_relative "cms/views/category_code_set/create_view"
require_relative "cms/views/category_code_set/edit_view"
require_relative "cms/views/category_code_set/delete_view"
require_relative "cms/views/defined_term/list_view"
require_relative "cms/views/defined_term/detail_view"
require_relative "cms/views/defined_term/create_view"
require_relative "cms/views/defined_term/edit_view"
require_relative "cms/views/defined_term/delete_view"
require_relative "cms/views/defined_term_set/list_view"
require_relative "cms/views/defined_term_set/detail_view"
require_relative "cms/views/defined_term_set/create_view"
require_relative "cms/views/defined_term_set/edit_view"
require_relative "cms/views/defined_term_set/delete_view"
require_relative "cms/views/comment/list_view"
require_relative "cms/views/comment/detail_view"
require_relative "cms/views/comment/create_view"
require_relative "cms/views/comment/edit_view"
require_relative "cms/views/comment/delete_view"
require_relative "cms/views/web_site/list_view"
require_relative "cms/views/web_site/detail_view"
require_relative "cms/views/web_site/create_view"
require_relative "cms/views/web_site/edit_view"
require_relative "cms/views/web_site/delete_view"
require_relative "cms/views/site_navigation_element/list_view"
require_relative "cms/views/site_navigation_element/detail_view"
require_relative "cms/views/site_navigation_element/create_view"
require_relative "cms/views/site_navigation_element/edit_view"
require_relative "cms/views/site_navigation_element/delete_view"

module Cms
  module Admin
    UUID_PATTERN = %r{\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z}i
    PUBLIC_DIR = File.expand_path("../public", __dir__)
    MAX_BODY_SIZE = 1024 * 1024

    ENTITY_ROUTES = [
      { "entity" => "BlogPosting", "plural" => "blog-postings", "list" => Cms::Views::BlogPosting::ListView, "detail" => Cms::Views::BlogPosting::DetailView, "create" => Cms::Views::BlogPosting::CreateView, "edit" => Cms::Views::BlogPosting::EditView, "delete" => Cms::Views::BlogPosting::DeleteView },
      { "entity" => "Person", "plural" => "persons", "list" => Cms::Views::Person::ListView, "detail" => Cms::Views::Person::DetailView, "create" => Cms::Views::Person::CreateView, "edit" => Cms::Views::Person::EditView, "delete" => Cms::Views::Person::DeleteView },
      { "entity" => "Organization", "plural" => "organizations", "list" => Cms::Views::Organization::ListView, "detail" => Cms::Views::Organization::DetailView, "create" => Cms::Views::Organization::CreateView, "edit" => Cms::Views::Organization::EditView, "delete" => Cms::Views::Organization::DeleteView },
      { "entity" => "WebPage", "plural" => "web-pages", "list" => Cms::Views::WebPage::ListView, "detail" => Cms::Views::WebPage::DetailView, "create" => Cms::Views::WebPage::CreateView, "edit" => Cms::Views::WebPage::EditView, "delete" => Cms::Views::WebPage::DeleteView },
      { "entity" => "ImageObject", "plural" => "image-objects", "list" => Cms::Views::ImageObject::ListView, "detail" => Cms::Views::ImageObject::DetailView, "create" => Cms::Views::ImageObject::CreateView, "edit" => Cms::Views::ImageObject::EditView, "delete" => Cms::Views::ImageObject::DeleteView },
      { "entity" => "VideoObject", "plural" => "video-objects", "list" => Cms::Views::VideoObject::ListView, "detail" => Cms::Views::VideoObject::DetailView, "create" => Cms::Views::VideoObject::CreateView, "edit" => Cms::Views::VideoObject::EditView, "delete" => Cms::Views::VideoObject::DeleteView },
      { "entity" => "AudioObject", "plural" => "audio-objects", "list" => Cms::Views::AudioObject::ListView, "detail" => Cms::Views::AudioObject::DetailView, "create" => Cms::Views::AudioObject::CreateView, "edit" => Cms::Views::AudioObject::EditView, "delete" => Cms::Views::AudioObject::DeleteView },
      { "entity" => "CategoryCode", "plural" => "category-codes", "list" => Cms::Views::CategoryCode::ListView, "detail" => Cms::Views::CategoryCode::DetailView, "create" => Cms::Views::CategoryCode::CreateView, "edit" => Cms::Views::CategoryCode::EditView, "delete" => Cms::Views::CategoryCode::DeleteView },
      { "entity" => "CategoryCodeSet", "plural" => "category-code-sets", "list" => Cms::Views::CategoryCodeSet::ListView, "detail" => Cms::Views::CategoryCodeSet::DetailView, "create" => Cms::Views::CategoryCodeSet::CreateView, "edit" => Cms::Views::CategoryCodeSet::EditView, "delete" => Cms::Views::CategoryCodeSet::DeleteView },
      { "entity" => "DefinedTerm", "plural" => "defined-terms", "list" => Cms::Views::DefinedTerm::ListView, "detail" => Cms::Views::DefinedTerm::DetailView, "create" => Cms::Views::DefinedTerm::CreateView, "edit" => Cms::Views::DefinedTerm::EditView, "delete" => Cms::Views::DefinedTerm::DeleteView },
      { "entity" => "DefinedTermSet", "plural" => "defined-term-sets", "list" => Cms::Views::DefinedTermSet::ListView, "detail" => Cms::Views::DefinedTermSet::DetailView, "create" => Cms::Views::DefinedTermSet::CreateView, "edit" => Cms::Views::DefinedTermSet::EditView, "delete" => Cms::Views::DefinedTermSet::DeleteView },
      { "entity" => "Comment", "plural" => "comments", "list" => Cms::Views::Comment::ListView, "detail" => Cms::Views::Comment::DetailView, "create" => Cms::Views::Comment::CreateView, "edit" => Cms::Views::Comment::EditView, "delete" => Cms::Views::Comment::DeleteView },
      { "entity" => "WebSite", "plural" => "web-sites", "list" => Cms::Views::WebSite::ListView, "detail" => Cms::Views::WebSite::DetailView, "create" => Cms::Views::WebSite::CreateView, "edit" => Cms::Views::WebSite::EditView, "delete" => Cms::Views::WebSite::DeleteView },
      { "entity" => "SiteNavigationElement", "plural" => "site-navigation-elements", "list" => Cms::Views::SiteNavigationElement::ListView, "detail" => Cms::Views::SiteNavigationElement::DetailView, "create" => Cms::Views::SiteNavigationElement::CreateView, "edit" => Cms::Views::SiteNavigationElement::EditView, "delete" => Cms::Views::SiteNavigationElement::DeleteView },
    ].freeze

    STATIC_TYPES = {
      ".css" => "text/css; charset=utf-8",
      ".js" => "application/javascript; charset=utf-8",
      ".svg" => "image/svg+xml",
      ".png" => "image/png",
      ".ico" => "image/x-icon",
    }.freeze

    STATUS_TEXT = {
      200 => "OK", 303 => "See Other", 400 => "Bad Request", 403 => "Forbidden",
      404 => "Not Found", 500 => "Internal Server Error",
    }.freeze

    SECURITY_HEADERS = [
      ["Cache-Control", "no-store"], ["X-Content-Type-Options", "nosniff"],
      ["X-Frame-Options", "DENY"], ["Referrer-Policy", "no-referrer"],
    ].freeze

    def self.html(status, html_str, set_cookies)
      pairs = [["Content-Type", "text/html; charset=utf-8"], ["Content-Length", html_str.bytesize.to_s]]
      SECURITY_HEADERS.each { |p| pairs << p }
      set_cookies.each { |c| pairs << ["Set-Cookie", c] }
      [status, pairs, html_str]
    end

    def self.redirect(location, status, set_cookies)
      pairs = [["Location", location], ["Content-Length", "0"]]
      set_cookies.each { |c| pairs << ["Set-Cookie", c] }
      [status, pairs, nil]
    end

    def self.send_response(response, set_cookies)
      if response.key?("redirect")
        redirect(response["redirect"], response["status"] || 303, set_cookies)
      else
        html(response["status"] || 200, response["html"], set_cookies)
      end
    end

    def self.send_static(rel_path, set_cookies)
      full = File.expand_path(rel_path, PUBLIC_DIR)
      return html(404, not_found["html"], set_cookies) unless full.start_with?(PUBLIC_DIR + File::SEPARATOR) && File.file?(full)
      ctype = STATIC_TYPES[File.extname(full).downcase] || "application/octet-stream"
      body = File.binread(full)
      [200, [["Content-Type", ctype], ["Content-Length", body.bytesize.to_s], ["Cache-Control", "public, max-age=300"]], body]
    end

    def self.index_page(user, csrf)
      items = ENTITY_ROUTES.map { |r| %(<li><a href="/#{r["plural"]}">#{Cms::Layout.escape_html(r["entity"])}</a></li>) }.join
      { "status" => 200,
        "html" => Cms::Layout.layout(title: "Dashboard", user: user, csrf: csrf,
                                     body: %(<p>Manage content for #{ENTITY_ROUTES.length} entity types.</p><ul>#{items}</ul>)) }
    end

    def self.not_found(user = nil, csrf = nil)
      { "status" => 404, "html" => Cms::Layout.layout(title: "Not Found", user: user, csrf: csrf, body: %(<p role="alert">Page not found.</p>)) }
    end

    def self.invalid_id(user = nil, csrf = nil)
      { "status" => 400, "html" => Cms::Layout.layout(title: "Invalid ID", user: user, csrf: csrf, body: %(<p role="alert">ID must be a valid UUID.</p>)) }
    end

    # Resolves and validates the session by asking the API who we are. A 401 (or no
    # account) means the session is gone — surfaced as SessionExpiredError.
    def self.require_user(token)
      r = Cms::ApiClient.me(token)
      account = r["body"].is_a?(Hash) ? r["body"]["account"] : nil
      raise Cms::ApiClient::SessionExpiredError if r["status"] == 401 || account.nil?
      account
    end

    def self.match_entity_route(path)
      ENTITY_ROUTES.each do |r|
        base = "/" + r["plural"]
        return [r, "list", nil] if path == base
        return [r, "new", nil] if path == base + "/new"
        if path.start_with?(base + "/")
          rest = path[(base.length + 1)..-1]
          if rest.include?("/")
            head, _, action = rest.partition("/")
            next unless ["edit", "delete"].include?(action)
            return [r, action, head]
          end
          return [r, "detail", rest]
        end
      end
      nil
    end

    def self.handle_get(path, session_token, csrf, set_cookies, full_target)
      if path == "/login"
        return redirect("/", 303, set_cookies) if session_token
        return send_response(Cms::Login.render_login(csrf: csrf), set_cookies)
      end
      return redirect("/login", 303, set_cookies) unless session_token
      user = require_user(session_token)
      api = Cms::ApiClient.api_for(session_token)
      return send_response(index_page(user, csrf), set_cookies) if path == "/"

      match = match_entity_route(path)
      return send_response(not_found(user, csrf), set_cookies) if match.nil?
      route, kind, item_id = match
      id_valid = item_id.nil? || UUID_PATTERN.match?(item_id)
      ctx = { "api" => api, "csrf" => csrf, "user" => user }

      return send_response(route["list"].render(ctx.merge("url" => full_target)), set_cookies) if kind == "list"
      return send_response(route["create"].render_form(ctx), set_cookies) if kind == "new"
      return send_response(invalid_id(user, csrf), set_cookies) unless id_valid
      return send_response(route["detail"].render(ctx.merge("id" => item_id)), set_cookies) if kind == "detail"
      return send_response(route["edit"].render_form(ctx.merge("id" => item_id)), set_cookies) if kind == "edit"
      return send_response(route["delete"].render_form(ctx.merge("id" => item_id)), set_cookies) if kind == "delete"
      send_response(not_found(user, csrf), set_cookies)
    end

    def self.handle_submit_result(result, view, ctx, set_cookies)
      return redirect(result["redirect"], result["status"] || 303, set_cookies) if result.key?("redirect")
      return html(result["status"] || 400, result["html"], set_cookies) if result.key?("html")
      send_response(view.render_form(ctx.merge("errors" => result["errors"] || [], "values" => result["values"] || {})), set_cookies)
    end

    def self.handle_post(path, form_raw, session_token, csrf, set_cookies)
      if path == "/login"
        pairs = Cms::Layout.parse_form_pairs(form_raw)
        username = (pairs["username"] || "").to_s.strip
        password = (pairs["password"] || "").to_s
        if username.empty? || password.empty?
          return send_response(Cms::Login.render_login(csrf: csrf, error: "Username and password are required.", username: username), set_cookies)
        end
        r = Cms::ApiClient.login(username, password)
        if r["status"] == 200 && r["body"].is_a?(Hash) && r["body"]["token"]
          return redirect("/", 303, set_cookies + [Cms::Auth.set_session_cookie(r["body"]["token"])])
        end
        return send_response(Cms::Login.render_login(csrf: csrf, error: "Invalid username or password.", username: username), set_cookies)
      end

      if path == "/logout"
        if session_token
          begin
            Cms::ApiClient.logout(session_token)
          rescue StandardError
            nil
          end
        end
        return redirect("/login", 303, set_cookies + [Cms::Auth.clear_session_cookie])
      end

      return redirect("/login", 303, set_cookies) unless session_token
      user = require_user(session_token)
      api = Cms::ApiClient.api_for(session_token)

      match = match_entity_route(path)
      return send_response(not_found(user, csrf), set_cookies) if match.nil?
      route, kind, item_id = match
      id_valid = item_id.nil? || UUID_PATTERN.match?(item_id)
      ctx = { "api" => api, "csrf" => csrf, "user" => user }

      if kind == "new"
        result = route["create"].handle_submit(ctx.merge("form" => form_raw))
        return handle_submit_result(result, route["create"], ctx, set_cookies)
      end
      return send_response(invalid_id(user, csrf), set_cookies) unless id_valid
      if kind == "edit"
        result = route["edit"].handle_submit(ctx.merge("id" => item_id, "form" => form_raw))
        return handle_submit_result(result, route["edit"], ctx.merge("id" => item_id), set_cookies)
      end
      if kind == "delete"
        return send_response(route["delete"].handle_submit(ctx.merge("id" => item_id)), set_cookies)
      end
      send_response(not_found(user, csrf), set_cookies)
    end

    def self.dispatch(method, path, full_target, cookie_header, form_raw)
      cookies = Cms::Auth.parse_cookies(cookie_header)
      session_token = cookies[Cms::Auth::SESSION_COOKIE]
      session_token = nil if session_token == ""
      # Issue a CSRF token if the browser has none; never rotate an existing one.
      csrf = cookies[Cms::Auth::CSRF_COOKIE]
      set_cookies = []
      if csrf.nil? || csrf.empty?
        csrf = Cms::Auth.random_token
        set_cookies << Cms::Auth.set_csrf_cookie(csrf)
      end

      begin
        if method == "GET" && path == "/health"
          body = %({"status":"ok"})
          return [200, [["Content-Type", "application/json"], ["Content-Length", body.bytesize.to_s]], body]
        end
        return send_static("style.css", set_cookies) if method == "GET" && path == "/style.css"

        if method == "POST"
          submitted = Cms::Layout.parse_form_pairs(form_raw)["_csrf"]
          submitted = submitted.first if submitted.is_a?(Array)
          submitted = "" if submitted.nil?
          unless Cms::Auth.csrf_valid?(cookies[Cms::Auth::CSRF_COOKIE], submitted)
            return html(403, Cms::Layout.layout(title: "Forbidden", body: %(<p role="alert">Invalid or missing CSRF token. Reload the form and try again.</p>)), set_cookies)
          end
          return handle_post(path, form_raw, session_token, csrf, set_cookies)
        end

        return handle_get(path, session_token, csrf, set_cookies, full_target) if method == "GET"

        html(404, not_found["html"], set_cookies)
      rescue Cms::ApiClient::SessionExpiredError
        redirect("/login", 303, set_cookies + [Cms::Auth.clear_session_cookie])
      rescue StandardError => e
        warn "[#{method} #{path}] #{e.class}: #{e.message}"
        html(500, Cms::Layout.layout(title: "Error", body: %(<p role="alert">Internal server error.</p>)), set_cookies)
      end
    end

    def self.write_response(socket, status, pairs, body)
      reason = STATUS_TEXT[status] || "OK"
      lines = ["HTTP/1.1 #{status} #{reason}"]
      pairs.each { |k, v| lines << "#{k}: #{v}" }
      lines << "Connection: close"
      data = (lines.join("\r\n") + "\r\n\r\n").b
      data << body.b if body
      socket.write(data)
    end

    def self.handle_connection(socket)
      socket.binmode
      request_line = socket.gets("\r\n")
      return if request_line.nil?
      request_line = request_line.chomp
      return if request_line.empty?
      parts = request_line.split(" ")
      return if parts.length < 2
      method = parts[0]
      target = parts[1]

      cookie_header = nil
      content_length = 0
      loop do
        line = socket.gets("\r\n")
        break if line.nil?
        line = line.chomp
        break if line.empty?
        low = line.downcase
        if low.start_with?("cookie:")
          cookie_header = line.split(":", 2)[1].to_s.strip
        elsif low.start_with?("content-length:")
          content_length = line.split(":", 2)[1].to_s.strip.to_i
        end
      end
      form_raw = (content_length > 0 && content_length <= MAX_BODY_SIZE) ? (socket.read(content_length) || "") : ""

      mark = target.index("?")
      path = mark ? target[0...mark] : target
      begin
        status, pairs, body = dispatch(method, path, target, cookie_header, form_raw)
      rescue StandardError => e
        warn "[#{method} #{path}] #{e.class}: #{e.message}"
        status, pairs, body = html(500, Cms::Layout.layout(title: "Error", body: %(<p role="alert">Internal server error.</p>)), [])
      end
      write_response(socket, status, pairs, body)
    rescue Errno::EPIPE, Errno::ECONNRESET, IOError
      nil
    ensure
      begin
        socket.close
      rescue StandardError
        nil
      end
    end

    def self.main
      port = (ENV["PORT"] || "5016").to_i
      host = ENV["HOST"] || "0.0.0.0"
      server = TCPServer.new(host, port)
      warn "CMS admin running at http://#{host}:#{port}"
      begin
        loop do
          client = server.accept
          Thread.new(client) { |sock| handle_connection(sock) }
        end
      rescue Interrupt
        nil
      ensure
        server.close
        warn "Server closed."
      end
    end
  end
end

Cms::Admin.main if $PROGRAM_NAME == __FILE__

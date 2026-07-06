require "minitest/autorun"
require "json"
require "net/http"
require "uri"
require "cgi"
require "socket"
require "rbconfig"

# Shared admin test harness. Spawns the auth-aware mock API plus the admin server
# against it, then drives the admin over HTTP with a cookie jar.
module AT
  SESSION_COOKIE = "cms_session"
  CSRF_COOKIE = "cms_csrf"

  SRC = File.expand_path("../src", __dir__)
  SERVER_PATH = File.join(SRC, "server.rb")
  MOCK_PATH = File.expand_path("mock_api.rb", __dir__)

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

  SAMPLES = {
    "BlogPosting" => {
      "headline" => "sample",
      "articleBody" => "sample",
      "author" => { "__ref" => "Person" },
      "url" => "https://example.com/x",
    },
    "Person" => {
      "name" => "sample",
    },
    "Organization" => {
      "name" => "sample",
    },
    "WebPage" => {
      "headline" => "sample",
    },
    "ImageObject" => {
      "contentUrl" => "https://example.com/x",
    },
    "VideoObject" => {
      "contentUrl" => "https://example.com/x",
    },
    "AudioObject" => {
      "contentUrl" => "https://example.com/x",
    },
    "CategoryCode" => {
      "name" => "sample",
      "codeValue" => "sample",
      "inCodeSet" => { "__ref" => "CategoryCodeSet" },
    },
    "CategoryCodeSet" => {
      "name" => "sample",
    },
    "DefinedTerm" => {
      "name" => "sample",
      "termCode" => "sample",
      "inDefinedTermSet" => { "__ref" => "DefinedTermSet" },
    },
    "DefinedTermSet" => {
      "name" => "sample",
    },
    "Comment" => {
      "text" => "sample",
      "author" => { "__ref" => "Person" },
      "about" => { "__ref" => "BlogPosting" },
    },
    "WebSite" => {
      "name" => "sample",
      "url" => "https://example.com/x",
    },
    "SiteNavigationElement" => {
      "name" => "sample",
      "url" => "https://example.com/x",
    },
  }.freeze

  ENTITIES = ["BlogPosting", "Person", "Organization", "WebPage", "ImageObject", "VideoObject", "AudioObject", "CategoryCode", "CategoryCodeSet", "DefinedTerm", "DefinedTermSet", "Comment", "WebSite", "SiteNavigationElement"].freeze

  ADMIN_USERNAME = "admin"
  ADMIN_PASSWORD = "admin-password"

  @seeded = {}
  @stack = nil

  def self.free_port
    s = TCPServer.new("127.0.0.1", 0)
    port = s.addr[1]
    s.close
    port
  end

  def self.wait_for_health(base_url, timeout = 10)
    deadline = Time.now + timeout
    while Time.now < deadline
      begin
        res = Net::HTTP.get_response(URI(base_url + "/health"))
        return true if res.code.to_i == 200
      rescue StandardError
        nil
      end
      sleep 0.05
    end
    false
  end

  class Stack
    attr_reader :api_base_url, :admin_base_url

    def initialize
      mock_port = AT.free_port
      admin_port = AT.free_port
      @mock_pid = Process.spawn({ "PORT" => mock_port.to_s }, RbConfig.ruby, AT::MOCK_PATH, out: File::NULL, err: File::NULL)
      @api_base_url = "http://127.0.0.1:#{mock_port}"
      raise "Mock API did not become healthy" unless AT.wait_for_health(@api_base_url)
      @admin_pid = Process.spawn({ "PORT" => admin_port.to_s, "API_BASE_URL" => @api_base_url },
                                 RbConfig.ruby, AT::SERVER_PATH, out: File::NULL, err: File::NULL)
      @admin_base_url = "http://127.0.0.1:#{admin_port}"
      raise "Admin did not become healthy" unless AT.wait_for_health(@admin_base_url)
    end

    def stop
      [@admin_pid, @mock_pid].each do |pid|
        next unless pid
        begin
          Process.kill("TERM", pid)
          Process.wait(pid)
        rescue StandardError
          nil
        end
      end
    end
  end

  def self.get_stack
    if @stack.nil?
      @stack = Stack.new
      stack = @stack
      Minitest.after_run { stack.stop }
    end
    @stack
  end

  def self.reset_seed_cache
    @seeded = {}
  end

  def self.http_request(method, url, body: nil, headers: nil)
    uri = URI(url)
    klass = { "GET" => Net::HTTP::Get, "POST" => Net::HTTP::Post }.fetch(method)
    req = klass.new(uri)
    (headers || {}).each { |k, v| req[k] = v }
    req.body = body if body
    status = nil
    hdrs = {}
    set_cookies = []
    resp_body = ""
    # Materialize status, headers, Set-Cookie and body inside the connection block:
    # reading them after the block (socket closed) loses the response's lazily-read
    # state on some Ruby versions.
    Net::HTTP.start(uri.hostname, uri.port, open_timeout: 10, read_timeout: 10) do |http|
      res = http.request(req)
      status = res.code.to_i
      res.each_header { |k, v| hdrs[k.downcase] = v }
      set_cookies = (res.get_fields("set-cookie") || []).map(&:to_s)
      resp_body = res.body.to_s
    end
    { "status" => status, "headers" => hdrs, "set_cookies" => set_cookies, "body" => resp_body }
  end

  # Cookie jar: a plain name -> value map. Values are stored as received (the server
  # escapes hex tokens to themselves) and re-sent verbatim.
  def self.apply_set_cookies(jar, set_cookies)
    set_cookies.each do |raw|
      first = raw.split(";", 2)[0].to_s.strip
      name, sep, value = first.partition("=")
      next if sep.empty? || name.empty?
      if value == ""
        jar.delete(name)
      else
        jar[name] = value
      end
    end
  end

  def self.cookie_header(jar)
    jar.map { |k, v| "#{k}=#{v}" }.join("; ")
  end

  def self.get_set_cookies(r)
    r["set_cookies"]
  end

  def self.api_token(jar)
    raw = jar[SESSION_COOKIE]
    raw.nil? ? nil : CGI.unescape(raw)
  end

  def self.admin_get(stack, path, jar = nil)
    headers = jar.nil? ? {} : { "Cookie" => cookie_header(jar) }
    r = http_request("GET", stack.admin_base_url + path, headers: headers)
    apply_set_cookies(jar, r["set_cookies"]) unless jar.nil?
    r
  end

  # with_csrf is positional, not a keyword: a Hash jar passed as the last positional
  # arg before a keyword param gets copied by Ruby's keyword-splitting, so cookie
  # mutations would never reach the caller's jar.
  def self.admin_post_form(stack, path, body, jar = nil, with_csrf = true)
    final_body = body || ""
    if with_csrf && !jar.nil? && jar[CSRF_COOKIE] && !final_body.include?("_csrf=")
      token = CGI.unescape(jar[CSRF_COOKIE])
      final_body = (final_body.empty? ? "" : final_body + "&") + "_csrf=" + CGI.escape(token)
    end
    headers = { "Content-Type" => "application/x-www-form-urlencoded" }
    headers["Cookie"] = cookie_header(jar) unless jar.nil?
    r = http_request("POST", stack.admin_base_url + path, body: final_body, headers: headers)
    apply_set_cookies(jar, r["set_cookies"]) unless jar.nil?
    r
  end

  # Full browser-like login: GET /login to obtain the csrf cookie, then POST the
  # credentials. Returns a cookie jar carrying the session and csrf cookies.
  def self.login_admin(stack)
    jar = {}
    admin_get(stack, "/login", jar)
    r = admin_post_form(stack, "/login",
                        "username=" + CGI.escape(ADMIN_USERNAME) + "&password=" + CGI.escape(ADMIN_PASSWORD), jar)
    raise "login_admin failed: expected 303, got #{r["status"]}" unless r["status"] == 303
    jar
  end

  def self.encode_one(v)
    return "" if v.nil?
    if v.is_a?(Hash)
      return "__needs_resolve__" if v.key?("__ref")
      return (v["alternateName"] || "").to_s if v["@type"] == "Language"
      return JSON.generate(v)
    end
    return (v ? "true" : "false") if v == true || v == false
    v.to_s
  end

  def self.resolve_refs(stack, jar, sample)
    resolved = {}
    sample.each do |key, value|
      if value.is_a?(Array)
        resolved[key] = value.map { |v| v.is_a?(Hash) && v.key?("__ref") ? ensure_entity(stack, v["__ref"], jar) : v }
      elsif value.is_a?(Hash) && value.key?("__ref")
        resolved[key] = ensure_entity(stack, value["__ref"], jar)
      else
        resolved[key] = value
      end
    end
    resolved
  end

  def self.seed_to_mock(stack, jar, entity, payload)
    uri = URI(stack.api_base_url + "/" + PLURALS[entity])
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{api_token(jar)}"
    req.body = JSON.generate(payload)
    res = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 10, read_timeout: 10) { |http| http.request(req) }
    raise "seed(#{entity}) failed: #{res.code} #{res.body}" unless res.code.to_i == 201
    JSON.parse(res.body)["id"]
  end

  def self.ensure_entity(stack, entity, jar)
    return @seeded[entity] if @seeded.key?(entity)
    sample = resolve_refs(stack, jar, SAMPLES[entity])
    @seeded[entity] = seed_to_mock(stack, jar, entity, sample)
  end

  def self.seed_with(stack, entity, overrides, jar)
    sample = resolve_refs(stack, jar, SAMPLES[entity])
    sample.merge!(overrides)
    seed_to_mock(stack, jar, entity, sample)
  end

  def self.form_body_for(stack, entity, jar)
    sample = resolve_refs(stack, jar, SAMPLES[entity])
    pairs = []
    sample.each do |key, value|
      if value.is_a?(Array)
        value.each { |vv| pairs << [key, encode_one(vv)] }
      else
        pairs << [key, encode_one(value)]
      end
    end
    pairs.map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join("&")
  end
end

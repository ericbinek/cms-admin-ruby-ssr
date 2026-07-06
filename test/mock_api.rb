require "socket"
require "json"
require "securerandom"
require "time"

# In-memory mock of the CMS API for admin conformance tests. Mirrors the real API's
# wire envelope AND its auth contract: /auth/login issues an opaque bearer token,
# /auth/me and /auth/logout validate it, and every entity route requires a live
# session (401 without). The seeded admin has full access.
module MockApi
  SCHEMAS = {
    "BlogPosting" => { "plural" => "blog-postings", "required" => ["headline", "articleBody", "author", "url"] },
    "Person" => { "plural" => "persons", "required" => ["name"] },
    "Organization" => { "plural" => "organizations", "required" => ["name"] },
    "WebPage" => { "plural" => "web-pages", "required" => ["headline"] },
    "ImageObject" => { "plural" => "image-objects", "required" => ["contentUrl"] },
    "VideoObject" => { "plural" => "video-objects", "required" => ["contentUrl"] },
    "AudioObject" => { "plural" => "audio-objects", "required" => ["contentUrl"] },
    "CategoryCode" => { "plural" => "category-codes", "required" => ["name", "codeValue", "inCodeSet"] },
    "CategoryCodeSet" => { "plural" => "category-code-sets", "required" => ["name"] },
    "DefinedTerm" => { "plural" => "defined-terms", "required" => ["name", "termCode", "inDefinedTermSet"] },
    "DefinedTermSet" => { "plural" => "defined-term-sets", "required" => ["name"] },
    "Comment" => { "plural" => "comments", "required" => ["text", "author", "about"] },
    "WebSite" => { "plural" => "web-sites", "required" => ["name", "url"] },
    "SiteNavigationElement" => { "plural" => "site-navigation-elements", "required" => ["name", "url"] },
  }.freeze

  ENTITY_BY_PLURAL = SCHEMAS.each_with_object({}) { |(name, s), h| h[s["plural"]] = name }.freeze

  ADMIN_USERNAME = "admin"
  ADMIN_PASSWORD = "admin-password"

  @lock = Mutex.new
  @store = SCHEMAS.keys.each_with_object({}) { |name, h| h[name] = {} }
  @sessions = {}
  @admin = { "id" => SecureRandom.uuid, "username" => ADMIN_USERNAME, "role" => "admin" }

  def self.now
    Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  def self.error(status, code, message, details, path)
    { "status" => status, "error" => code, "message" => message, "details" => details, "path" => path }
  end

  def self.unauthorized(path)
    error(401, "UNAUTHORIZED", "Authentication is required, or the session is invalid or expired.", [], path)
  end

  def self.validate_required(entity, data, partial)
    return [] if partial
    missing = []
    SCHEMAS[entity]["required"].each do |f|
      v = data[f]
      missing << %(Field "#{f}" is required.) if v.nil? || v == "" || (v.is_a?(Array) && v.empty?)
    end
    missing
  end

  def self.bearer_token(headers)
    header = headers["authorization"]
    return nil if header.nil?
    parts = header.strip.split(" ", 2)
    parts.length == 2 && parts[0] == "Bearer" ? parts[1] : nil
  end

  def self.account_for(headers)
    token = bearer_token(headers)
    token.nil? ? nil : @sessions[token]
  end

  def self.parse_query(query)
    result = {}
    (query || "").split("&").each do |pair|
      next if pair.empty?
      k, _, v = pair.partition("=")
      result[k] = v
    end
    result
  end

  def self.parse_body(raw)
    return {} if raw.nil? || raw.empty?
    data = JSON.parse(raw)
    data.is_a?(Hash) ? data : {}
  end

  def self.handle(method, path, query, body_raw, headers)
    request_path = "#{method} #{path}"
    return [200, { "status" => "ok" }] if method == "GET" && path == "/health"

    if path == "/auth/login"
      return [405, error(405, "METHOD_NOT_ALLOWED", "Method not allowed.", [], request_path)] unless method == "POST"
      data = parse_body(body_raw)
      unless data["username"].is_a?(String) && data["password"].is_a?(String)
        return [400, error(400, "VALIDATION_ERROR", "Invalid request data.", ['Fields "username" and "password" are required.'], request_path)]
      end
      return [401, unauthorized(request_path)] unless data["username"] == ADMIN_USERNAME && data["password"] == ADMIN_PASSWORD
      token = SecureRandom.uuid
      @sessions[token] = @admin
      return [200, {
        "token" => token,
        "account" => { "id" => @admin["id"], "username" => @admin["username"], "role" => @admin["role"] },
        "expiresAt" => (Time.now.utc + 8 * 3600).strftime("%Y-%m-%dT%H:%M:%SZ"),
      }]
    end

    if path == "/auth/logout"
      return [405, error(405, "METHOD_NOT_ALLOWED", "Method not allowed.", [], request_path)] unless method == "POST"
      token = bearer_token(headers)
      return [401, unauthorized(request_path)] if token.nil? || !@sessions.key?(token)
      @sessions.delete(token)
      return [204, nil]
    end

    if path == "/auth/me"
      return [405, error(405, "METHOD_NOT_ALLOWED", "Method not allowed.", [], request_path)] unless method == "GET"
      account = account_for(headers)
      return [401, unauthorized(request_path)] if account.nil?
      return [200, { "account" => { "id" => account["id"], "username" => account["username"], "role" => account["role"] } }]
    end

    account = account_for(headers)
    return [401, unauthorized(request_path)] if account.nil?

    seg = path.split("/").reject(&:empty?)
    return [404, error(404, "ROUTE_NOT_FOUND", "No route matches this request.", [], request_path)] unless (1..2).cover?(seg.length)
    entity = ENTITY_BY_PLURAL[seg[0]]
    return [404, error(404, "ROUTE_NOT_FOUND", "No route matches this request.", [], request_path)] if entity.nil?
    collection = @store[entity]

    if seg.length == 1
      if method == "GET"
        items = collection.values
        params = parse_query(query)
        sort = params["sort"] || "dateCreated"
        order = params["order"] || "desc"
        items = items.sort_by { |i| (i[sort] || "").to_s }
        items = items.reverse unless order == "asc"
        total = items.length
        limit = [(params["limit"] || "20").to_i, 100].min
        offset = (params["offset"] || "0").to_i
        return [200, { "items" => items[offset, limit] || [], "total" => total }]
      end
      if method == "POST"
        data = parse_body(body_raw)
        errs = validate_required(entity, data, false)
        return [400, error(400, "VALIDATION_ERROR", "Invalid request data.", errs, request_path)] unless errs.empty?
        item = { "@context" => "https://schema.org", "@type" => entity }.merge(data)
        item.merge!("id" => SecureRandom.uuid, "dateCreated" => now, "dateModified" => now)
        collection[item["id"]] = item
        return [201, item]
      end
      return [405, error(405, "METHOD_NOT_ALLOWED", "Method not allowed.", [], request_path)]
    end

    item_id = seg[1].downcase
    current = collection[item_id]

    if method == "GET"
      return [404, error(404, "NOT_FOUND", "#{entity} not found.", [], request_path)] if current.nil?
      return [200, current]
    end
    if method == "PUT"
      return [404, error(404, "NOT_FOUND", "#{entity} not found.", [], request_path)] if current.nil?
      data = parse_body(body_raw)
      errs = validate_required(entity, data, true)
      return [400, error(400, "VALIDATION_ERROR", "Invalid request data.", errs, request_path)] unless errs.empty?
      updated = current.merge(data).merge("id" => current["id"], "dateCreated" => current["dateCreated"],
                                          "dateModified" => now, "@context" => current["@context"] || "https://schema.org",
                                          "@type" => current["@type"] || entity)
      collection[item_id] = updated
      return [200, updated]
    end
    if method == "DELETE"
      return [404, error(404, "NOT_FOUND", "#{entity} not found.", [], request_path)] if current.nil?
      collection.delete(item_id)
      return [204, nil]
    end
    [405, error(405, "METHOD_NOT_ALLOWED", "Method not allowed.", [], request_path)]
  end

  def self.write_json(socket, status, data)
    if status == 204 || data.nil?
      socket.write("HTTP/1.1 #{status} OK\r\nConnection: close\r\n\r\n")
      return
    end
    body = JSON.generate(data)
    headers = ["HTTP/1.1 #{status} OK", "Content-Type: application/json; charset=utf-8", "Content-Length: #{body.bytesize}", "Connection: close"]
    socket.write((headers.join("\r\n") + "\r\n\r\n" + body).b)
  end

  def self.handle_connection(socket)
    socket.binmode
    request_line = socket.gets("\r\n")
    return if request_line.nil?
    parts = request_line.chomp.split(" ")
    return if parts.length < 2
    method = parts[0]
    target = parts[1]
    headers = {}
    content_length = 0
    loop do
      line = socket.gets("\r\n")
      break if line.nil?
      line = line.chomp
      break if line.empty?
      name, sep, value = line.partition(":")
      next if sep.empty?
      headers[name.strip.downcase] = value.strip
    end
    content_length = headers["content-length"].to_i if headers.key?("content-length")
    body_raw = content_length > 0 ? socket.read(content_length) : nil
    mark = target.index("?")
    path = mark ? target[0...mark] : target
    query = mark ? target[(mark + 1)..-1] : ""
    begin
      status, data = @lock.synchronize { handle(method, path, query, body_raw, headers) }
    rescue JSON::ParserError
      status, data = [400, error(400, "INVALID_JSON", "Request body is not valid JSON.", [], "#{method} #{path}")]
    rescue StandardError => e
      status, data = [500, error(500, "INTERNAL_ERROR", "Internal server error: #{e}", [], "#{method} #{path}")]
    end
    write_json(socket, status, data)
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
    port = (ENV["PORT"] || "0").to_i
    host = ENV["HOST"] || "127.0.0.1"
    server = TCPServer.new(host, port)
    warn "mock api ready on #{server.addr[1]}"
    loop do
      client = server.accept
      Thread.new(client) { |sock| handle_connection(sock) }
    end
  end
end

MockApi.main if $PROGRAM_NAME == __FILE__

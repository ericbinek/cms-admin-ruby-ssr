require "json"
require "net/http"
require "uri"
require "cgi"

module Cms
  module ApiClient
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

    DEFAULT_PORT = 3016

    # Raised when a bound request gets 401 from the API — the session is invalid or
    # expired upstream. The server catches it, clears the cookie, and redirects.
    class SessionExpiredError < StandardError
      def initialize
        super("Session expired.")
      end
    end

    def self.base_url
      (ENV["API_BASE_URL"] || "http://localhost:#{DEFAULT_PORT}").sub(%r{/+\z}, "")
    end

    def self.plural_of(entity)
      raise "Unknown entity for plural lookup: #{entity}" unless PLURALS.key?(entity)
      PLURALS[entity]
    end

    def self.request(method, path, token: nil, body: nil)
      uri = URI(base_url + path)
      klass = { "GET" => Net::HTTP::Get, "POST" => Net::HTTP::Post, "PUT" => Net::HTTP::Put, "DELETE" => Net::HTTP::Delete }.fetch(method)
      req = klass.new(uri)
      req["Accept"] = "application/json"
      req["Authorization"] = "Bearer #{token}" if token
      unless body.nil?
        req.body = JSON.generate(body)
        req["Content-Type"] = "application/json"
      end
      res = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 10, read_timeout: 10) { |http| http.request(req) }
      raw = res.body
      parsed = nil
      if raw && !raw.empty?
        begin
          parsed = JSON.parse(raw)
        rescue JSON::ParserError
          parsed = nil
        end
      end
      { "status" => res.code.to_i, "body" => parsed, "etag" => res["ETag"] }
    rescue StandardError => e
      { "status" => 0, "body" => { "message" => "ApiClient request failed: #{e}" }, "etag" => nil }
    end

    # Auth routes — driven by the server's login/logout flow, not by the views.
    def self.login(username, password)
      request("POST", "/auth/login", body: { "username" => username, "password" => password })
    end

    def self.logout(token)
      request("POST", "/auth/logout", token: token)
    end

    def self.me(token)
      request("GET", "/auth/me", token: token)
    end

    # A session-bound client. Every entity call carries the bearer token; a 401
    # becomes a SessionExpiredError.
    class BoundClient
      def initialize(token)
        @token = token
      end

      def authed(method, path, body = nil)
        r = Cms::ApiClient.request(method, path, token: @token, body: body)
        raise Cms::ApiClient::SessionExpiredError if r["status"] == 401
        r
      end

      def list(entity, query = nil)
        cleaned = (query || {}).reject { |_, v| v.nil? || v == "" }
        qs = cleaned.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join("&")
        authed("GET", "/" + Cms::ApiClient.plural_of(entity) + (qs.empty? ? "" : "?" + qs))
      end

      def get(entity, id)
        authed("GET", "/" + Cms::ApiClient.plural_of(entity) + "/" + CGI.escape(id))
      end

      def create(entity, payload)
        authed("POST", "/" + Cms::ApiClient.plural_of(entity), payload)
      end

      def update(entity, id, payload)
        authed("PUT", "/" + Cms::ApiClient.plural_of(entity) + "/" + CGI.escape(id), payload)
      end

      def remove(entity, id)
        authed("DELETE", "/" + Cms::ApiClient.plural_of(entity) + "/" + CGI.escape(id))
      end
    end

    def self.api_for(token)
      BoundClient.new(token)
    end
  end
end

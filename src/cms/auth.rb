require "cgi"
require "securerandom"

module Cms
  module Auth
    # Cookie names are admin-frontend internal; the API never reads them. The session
    # cookie carries the API bearer token, the csrf cookie the synchronizer token.
    SESSION_COOKIE = "cms_session"
    CSRF_COOKIE = "cms_csrf"

    # Both cookies live at most as long as the API session cap (8h). Secure is on
    # only behind HTTPS (COOKIE_SECURE=true). SameSite=Strict and HttpOnly are always
    # on — the server renders the csrf token into forms itself.
    MAX_AGE = 60 * 60 * 8

    def self.cookie_secure?
      (ENV["COOKIE_SECURE"] || "").downcase == "true"
    end

    def self.parse_cookies(header)
      out = {}
      return out if header.nil? || header.empty?
      header.split(/;\s*/).each do |pair|
        next if pair.empty?
        name, sep, value = pair.partition("=")
        next if sep.empty?
        out[name.strip] = CGI.unescape(value)
      end
      out
    end

    def self.serialize(name, value, max_age)
      parts = ["#{name}=#{CGI.escape(value)}", "Path=/", "HttpOnly", "SameSite=Strict", "Max-Age=#{max_age}"]
      parts << "Secure" if cookie_secure?
      parts.join("; ")
    end

    def self.set_session_cookie(token)
      serialize(SESSION_COOKIE, token, MAX_AGE)
    end

    def self.clear_session_cookie
      serialize(SESSION_COOKIE, "", 0)
    end

    def self.set_csrf_cookie(token)
      serialize(CSRF_COOKIE, token, MAX_AGE)
    end

    def self.random_token
      SecureRandom.hex(32)
    end

    def self.secure_compare(a, b)
      return false unless a.bytesize == b.bytesize
      left = a.unpack("C*")
      result = 0
      b.each_byte.with_index { |byte, i| result |= byte ^ left[i] }
      result == 0
    end

    # Constant-time comparison of the cookie token against the submitted form token.
    # Non-strings or unequal lengths fail closed.
    def self.csrf_valid?(cookie_token, form_token)
      return false unless cookie_token.is_a?(String) && form_token.is_a?(String)
      return false if cookie_token.empty? || cookie_token.bytesize != form_token.bytesize
      secure_compare(cookie_token, form_token)
    end
  end
end

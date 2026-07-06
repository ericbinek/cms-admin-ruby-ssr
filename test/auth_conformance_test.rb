require_relative "test_helper"

class AdminAuthConformanceTest < Minitest::Test
  ENTITY = "BlogPosting"
  BASE = "/blog-postings"

  class << self
    attr_accessor :stack
  end

  def stack
    self.class.stack
  end

  def setup
    self.class.stack = AT.get_stack if self.class.stack.nil?
  end

  def test_unauthenticated_dashboard_redirects_to_login
    r = AT.admin_get(stack, "/")
    assert_equal 303, r["status"]
    assert_equal "/login", r["headers"]["location"]
  end

  def test_unauthenticated_entity_route_redirects_to_login
    r = AT.admin_get(stack, BASE)
    assert_equal 303, r["status"]
    assert_equal "/login", r["headers"]["location"]
  end

  def test_get_login_renders_a_sign_in_form
    r = AT.admin_get(stack, "/login")
    assert_equal 200, r["status"]
    assert_match(/<form[^>]+method="POST"[^>]+action="\/login"/, r["body"])
    assert_includes r["body"], 'type="password"'
    assert_includes r["body"], 'name="_csrf"'
  end

  def test_login_with_wrong_credentials_returns_401_with_an_alert
    jar = {}
    AT.admin_get(stack, "/login", jar)
    r = AT.admin_post_form(stack, "/login", "username=admin&password=wrong", jar)
    assert_equal 401, r["status"]
    assert_match(/role="alert"/, r["body"])
  end

  def test_login_sets_an_httponly_samesite_strict_session_cookie_and_redirects
    jar = {}
    AT.admin_get(stack, "/login", jar)
    r = AT.admin_post_form(stack, "/login", "username=admin&password=admin-password", jar)
    assert_equal 303, r["status"]
    assert_equal "/", r["headers"]["location"]
    set_cookies = AT.get_set_cookies(r).join("\n")
    assert_match(/#{AT::SESSION_COOKIE}=/, set_cookies)
    assert_match(/HttpOnly/i, set_cookies)
    assert_match(/SameSite=Strict/i, set_cookies)
  end

  def test_authenticated_dashboard_renders_after_login
    jar = AT.login_admin(stack)
    r = AT.admin_get(stack, "/", jar)
    assert_equal 200, r["status"]
    assert_includes r["body"], "Dashboard"
    assert_includes r["body"], "Sign out"
  end

  def test_state_changing_post_without_a_csrf_token_is_rejected_with_403
    jar = AT.login_admin(stack)
    body = AT.form_body_for(stack, ENTITY, jar)
    r = AT.admin_post_form(stack, BASE + "/new", body, jar, false)
    assert_equal 403, r["status"]
  end

  def test_state_changing_post_with_a_wrong_csrf_token_is_rejected_with_403
    jar = AT.login_admin(stack)
    body = AT.form_body_for(stack, ENTITY, jar) + "&_csrf=not-the-real-token"
    r = AT.admin_post_form(stack, BASE + "/new", body, jar, false)
    assert_equal 403, r["status"]
  end

  def test_logout_clears_the_session_and_protected_routes_redirect_again
    jar = AT.login_admin(stack)
    out = AT.admin_post_form(stack, "/logout", "", jar)
    assert_equal 303, out["status"]
    assert_equal "/login", out["headers"]["location"]
    after = AT.admin_get(stack, "/", jar)
    assert_equal 303, after["status"]
    assert_equal "/login", after["headers"]["location"]
  end
end

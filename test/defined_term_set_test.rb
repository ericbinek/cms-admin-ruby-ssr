require_relative "test_helper"

class DefinedTermSetAdminTest < Minitest::Test
  ENTITY = "DefinedTermSet"
  BASE = "/defined-term-sets"

  class << self
    attr_accessor :stack, :jar
  end

  def stack
    self.class.stack
  end

  def jar
    self.class.jar
  end

  def setup
    if self.class.stack.nil?
      self.class.stack = AT.get_stack
      self.class.jar = AT.login_admin(self.class.stack)
    end
    AT.reset_seed_cache
  end

  def test_unauthenticated_list_redirects_to_login
    r = AT.admin_get(stack, BASE)
    assert_equal 303, r["status"]
    assert_equal "/login", r["headers"]["location"]
  end

  def test_get_list_renders_semantic_page
    AT.ensure_entity(stack, ENTITY, jar)
    r = AT.admin_get(stack, BASE, jar)
    assert_equal 200, r["status"]
    assert_match(/<table\b/, r["body"])
    assert_match(/<caption>/, r["body"])
    assert_includes r["body"], ENTITY
  end

  def test_get_new_renders_a_form_with_a_csrf_field
    r = AT.admin_get(stack, BASE + "/new", jar)
    assert_equal 200, r["status"]
    assert_match(/<form[^>]+method="POST"/, r["body"])
    assert_includes r["body"], 'name="_csrf"'
    assert_includes r["body"], %(action="#{BASE}/new")
  end

  def test_post_new_with_valid_form_redirects_to_detail
    body = AT.form_body_for(stack, ENTITY, jar)
    r = AT.admin_post_form(stack, BASE + "/new", body, jar)
    assert_equal 303, r["status"]
    loc = r["headers"]["location"] || ""
    assert loc.start_with?(BASE + "/"), "expected redirect to #{BASE}/<id>, got #{loc}"
  end

  def test_post_new_with_empty_form_returns_400_or_303
    r = AT.admin_post_form(stack, BASE + "/new", "", jar)
    return if r["status"] == 303
    assert_equal 400, r["status"]
    assert_match(/role="alert"/, r["body"])
  end

  def test_get_detail_returns_200_with_article_markup
    item_id = AT.ensure_entity(stack, ENTITY, jar)
    r = AT.admin_get(stack, BASE + "/" + item_id, jar)
    assert_equal 200, r["status"]
    assert_match(/<article\b/, r["body"])
    assert_match(/<dl>/, r["body"])
    assert_includes r["body"], item_id
  end

  def test_get_edit_renders_pre_filled_form
    item_id = AT.ensure_entity(stack, ENTITY, jar)
    r = AT.admin_get(stack, BASE + "/" + item_id + "/edit", jar)
    assert_equal 200, r["status"]
    assert_match(/<form[^>]+method="POST"/, r["body"])
    assert_includes r["body"], 'name="_csrf"'
  end

  def test_post_edit_redirects_back_to_detail
    item_id = AT.ensure_entity(stack, ENTITY, jar)
    body = AT.form_body_for(stack, ENTITY, jar)
    r = AT.admin_post_form(stack, BASE + "/" + item_id + "/edit", body, jar)
    assert_equal 303, r["status"]
    assert_equal BASE + "/" + item_id, r["headers"]["location"]
  end

  def test_get_delete_renders_confirmation_form
    item_id = AT.ensure_entity(stack, ENTITY, jar)
    r = AT.admin_get(stack, BASE + "/" + item_id + "/delete", jar)
    assert_equal 200, r["status"]
    assert_match(/<form[^>]+method="POST"/, r["body"])
    assert_includes r["body"], "Confirm Delete"
  end

  def test_post_delete_redirects_to_list
    item_id = AT.ensure_entity(stack, ENTITY, jar)
    r = AT.admin_post_form(stack, BASE + "/" + item_id + "/delete", "", jar)
    assert_equal 303, r["status"]
    assert_equal BASE, r["headers"]["location"]
  end

  def test_get_detail_with_non_uuid_id_returns_400_with_alert
    r = AT.admin_get(stack, BASE + "/not-a-uuid", jar)
    assert_equal 400, r["status"]
    assert_match(/role="alert"/, r["body"])
  end

  def test_get_detail_of_missing_id_renders_404_page
    r = AT.admin_get(stack, BASE + "/00000000-0000-0000-0000-000000000000", jar)
    assert_equal 404, r["status"]
    assert_match(/role="alert"/, r["body"])
  end

  def test_navigation_includes_self_link_with_aria_current
    AT.ensure_entity(stack, ENTITY, jar)
    r = AT.admin_get(stack, BASE, jar)
    assert_match(/aria-current="page"/, r["body"])
  end

  def test_list_view_paginates_with_previous_and_next_navigation
    AT.seed_with(stack, ENTITY, {}, jar)
    AT.seed_with(stack, ENTITY, {}, jar)
    AT.seed_with(stack, ENTITY, {}, jar)
    first = AT.admin_get(stack, BASE + "?limit=2&offset=0", jar)
    assert_equal 200, first["status"]
    assert_includes first["body"], 'rel="next"'
    assert_includes first["body"], "offset=2"
    refute_includes first["body"], 'rel="prev"'
    second = AT.admin_get(stack, BASE + "?limit=2&offset=2", jar)
    assert_equal 200, second["status"]
    assert_includes second["body"], 'rel="prev"'
  end

  def test_stored_dangerous_urls_render_as_inert_text_never_as_links
    js_id = AT.seed_with(stack, ENTITY, { "url" => "javascript:alert(1)" }, jar)
    js_html = AT.admin_get(stack, BASE + "/" + js_id, jar)["body"]
    assert_includes js_html, "javascript:alert(1)"
    refute_includes js_html, 'href="javascript:'

    data_id = AT.seed_with(stack, ENTITY, { "url" => "data:text/html,x" }, jar)
    data_html = AT.admin_get(stack, BASE + "/" + data_id, jar)["body"]
    assert_includes data_html, "data:text/html,x"
    refute_includes data_html, 'href="data:'
  end

  def test_stored_http_url_renders_as_a_clickable_link
    item_id = AT.seed_with(stack, ENTITY, { "url" => "https://example.com/profile" }, jar)
    html = AT.admin_get(stack, BASE + "/" + item_id, jar)["body"]
    assert_includes html, 'href="https://example.com/profile"'
  end
end

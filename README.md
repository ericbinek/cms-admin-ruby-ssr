# schema.org aligned CMS Admin (Ruby)

[![Tests](https://github.com/ericbinek/cms-admin-ruby-ssr/actions/workflows/test.yml/badge.svg)](https://github.com/ericbinek/cms-admin-ruby-ssr/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)
![Status](https://img.shields.io/badge/status-work_in_progress-orange.svg)
![Build in public](https://img.shields.io/badge/build-in_public-ff69b4.svg)
![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)
![Ruby 3.4](https://img.shields.io/badge/Ruby-3.4-red.svg)

A server rendered admin interface for a schema.org aligned CMS, written in plain Ruby 3.4.

There is no `Gemfile` and no bundler step. It serves semantic HTML from a hand-written HTTP/1.1 layer over `socket`/`TCPServer`, with no template engine and no build step.

It is login protected and offers full create, edit, and delete management for 14 schema.org entity types such as BlogPosting, Person, and Organization. It is a stateless proxy: the browser holds an HttpOnly session cookie, the server translates it into a bearer token for the CMS API, and the API stays the authority for authentication and permissions. State changing forms carry a CSRF synchronizer token.

A conformance test suite defines the markup and behavior.

## Status: work in progress (v0.1.0)

This is an ongoing build-in-public project, shared only for community and communication purposes. Do not deploy it in production. Do not rely on its interfaces or data format remaining stable.

## No bundler

There is no `Gemfile` and nothing to `bundle install`. The whole thing is Ruby's core and standard library: `socket`, `net/http`, `json`, `minitest`. Run it with the system `ruby`.

## Requirements

- Ruby 3.4 or newer

## Installation

```sh
git clone https://github.com/ericbinek/cms-admin-ruby-ssr.git
cd cms-admin-ruby-ssr
cp .env.example .env
```

## Running

```sh
ruby src/server.rb
```

The server listens on `PORT` (default 5016).

## Usage

Open http://localhost:5016/ in a browser and sign in. Accounts live in the CMS API; there is no self-registration.
Each entity has a list view at `/<plural>`, a detail view at `/<plural>/:id`, and create/edit/delete flows.

Configure the upstream API via the `API_BASE_URL` environment variable. Set `COOKIE_SECURE=true` when serving over HTTPS.

## Entities

- `BlogPosting`
- `Person`
- `Organization`
- `WebPage`
- `ImageObject`
- `VideoObject`
- `AudioObject`
- `CategoryCode`
- `CategoryCodeSet`
- `DefinedTerm`
- `DefinedTermSet`
- `Comment`
- `WebSite`
- `SiteNavigationElement`

## Testing

```sh
ruby -e "Dir.glob('test/*_test.rb').sort.each { |f| require File.expand_path(f) }"
```

## Contributing

Contributions are welcome. This is a build-in-public project, so issues, questions, and ideas count as much as pull requests. If you send code, keep it on Ruby's core and standard library with no new dependencies, and keep the conformance suite green, since the tests are the contract.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guidelines.

## License

MIT. See [LICENSE](LICENSE).

# Publishing `html2img-client` to RubyGems

Written for someone who has published to Packagist and npm, and now to PyPI,
but not to RubyGems.

## How RubyGems compares

| | Packagist | npm | PyPI | RubyGems |
| --- | --- | --- | --- | --- |
| What you push | nothing, it reads git tags | a tarball | `.whl` + `.tar.gz` | a single `.gem` file |
| Where the version lives | git tag | `package.json` | project metadata | `lib/html2img/version.rb` |
| Delete a release? | yes | within 72 hours | no, yank only | yank; deletion only within 24 hours and discouraged |
| Re-upload a version? | n/a | no | no | no |
| Namespaces | vendor prefix | scopes | none | none |

If you have read [PUBLISHING.md in html2img-python](https://github.com/html2img/html2img-python/blob/main/PUBLISHING.md),
RubyGems will feel familiar: same one-way door on version numbers, same absence
of namespaces, and the same trusted-publishing story. The differences worth
knowing are in [the release flow](#the-release-flow) below.

## The gem name

`html2img` was already taken on RubyGems by an unrelated 0.0.5 gem, so this gem
is **`html2img-client`**, matching `html2img-client` on PyPI and
`@html2img/client` on npm.

Ruby's hyphen convention makes this tidier than it was on PyPI:

- `require "html2img/client"` — the canonical require path
- `require "html2img-client"` — what Bundler requires by default, a one-line shim
- `Html2img::Client` — the namespace

Because the gem deliberately ships no top-level `lib/html2img.rb`, it cannot
collide with the squatted `html2img` gem even if both are installed.

## The account

Same reasoning as PyPI: register **`html2img` as a brand account**, on
`rubygems@html2img.com` (a mailbox on the domain, so it travels with the
business), with MFA enabled and the seed in the company password manager.

The gemspec already sets `"rubygems_mfa_required" => "true"`, which means
RubyGems refuses to accept a push from an account without MFA. Keep it.

**Organizations** exist on RubyGems.org but are in limited private beta — you
have to email `support@rubygems.org` to be let in, and there is no public
pricing. Not worth chasing. A brand account plus trusted publishing gets you the
same practical result, and gems can be transferred to an organization later.

## The release flow

This is the one place RubyGems genuinely differs from PyPI, and it is worth
understanding before your first release.

On PyPI, our workflow triggers on a **GitHub release** you create from a tag you
pushed. On RubyGems, the official [`rubygems/release-gem`](https://github.com/rubygems/release-gem)
action runs `rake release`, which **creates and pushes the git tag itself**. So
the tag must *not* exist when the workflow runs, and the workflow is triggered by
hand instead.

```
PyPI:      bump -> commit -> tag -> push tag -> GitHub release -> workflow publishes
RubyGems:  bump -> commit -> push -> run workflow -> workflow tags, pushes and publishes
```

## One-time setup

### 1. The account

Register at [rubygems.org/sign_up](https://rubygems.org/sign_up) as `html2img`
with the domain mailbox, and enable MFA (Settings → Multi-factor authentication)
with "UI and API" or "UI and gem signin" level.

### 2. The pending trusted publisher

Because RubyGems supports *pending* publishers, the first release needs no API
key either. At
[rubygems.org/settings/trusted_publishers](https://rubygems.org/settings/trusted_publishers)
→ **Create**:

| Field | Value |
| --- | --- |
| RubyGems gem name | `html2img-client` |
| Repository owner | `html2img` |
| Repository name | `html2img-ruby` |
| Workflow filename | `publish.yml` |
| Environment | `release` |

Then create the `release` environment in the GitHub repo under
**Settings → Environments**. No secrets needed.

As on PyPI, a pending publisher does not reserve the gem name — it is claimed on
first push.

### 3. Check it locally

```bash
gem build html2img-client.gemspec
gem install --local ./html2img-client-1.0.0.gem
ruby -e 'require "html2img-client"; puts Html2img::VERSION'
HTML2IMG_API_KEY=your-key html2img test
```

`gem build` prints every field it will publish. Read it once: the summary,
the homepage, the licence and the metadata links all appear on the gem's
RubyGems page and are the highest-authority backlinks the gem produces.

## Every release

```bash
# 1. Bump the version in lib/html2img/version.rb
# 2. Move the Unreleased entries in CHANGELOG.md under the new version, with a date
# 3. Commit and push — do NOT tag, the workflow does that

git commit -am "Release 1.1.0"
git push origin main
```

Then **Actions → Publish → Run workflow**. It runs the specs and RuboCop, builds
the gem, tags `v1.1.0`, pushes the tag, and publishes to RubyGems over OIDC.

Afterwards, optionally add release notes for the tag it created:

```bash
git pull --tags
gh release create v1.1.0 --generate-notes
```

Confirm with `gem list -r html2img-client --all` and check the gem page.

## The release checklist

```
[ ] CI green on main across the Ruby matrix
[ ] Version bumped in lib/html2img/version.rb
[ ] CHANGELOG.md updated with the new version and date
[ ] Committed and pushed, with no local tag for this version
[ ] Actions -> Publish -> Run workflow
[ ] gem install html2img-client in a clean container and run `html2img test`
[ ] Gem page renders correctly on rubygems.org
```

## If something goes wrong

- **"Repushing of gem versions is not allowed"** — that version is spent. Bump
  and release again.
- **A broken release is live** — `gem yank html2img-client -v 1.1.0`. Yanking
  hides it from new resolutions while leaving it installable for anyone who
  pins it. It does *not* free the version number. Deletion is possible only
  within 24 hours of the push and is strongly discouraged.
- **"Tag v1.1.0 has already been created"** — you tagged locally before running
  the workflow. Delete the tag (`git tag -d v1.1.0 && git push --delete origin
  v1.1.0`) and run the workflow again.
- **The workflow cannot authenticate** — the job needs both `id-token: write`
  and `contents: write`, and the `environment: name: release` block must match
  what you configured on RubyGems exactly.
- **"Your account must have MFA enabled"** — the gemspec sets
  `rubygems_mfa_required`, so the pushing account needs MFA at the "UI and API"
  level.

## Making the gem findable

1. **The gemspec metadata** drives the sidebar on the gem page: homepage,
   source, changelog, bug tracker and documentation links are all set. Keep
   `documentation_uri` pointing at the Ruby guide.
2. **[The Ruby Toolbox](https://www.ruby-toolbox.com/)** categorises gems from
   RubyGems and GitHub automatically; make sure the GitHub description and
   topics are set (`ruby`, `html-to-image`, `screenshot`, `og-image`,
   `html-to-pdf`).
3. **A Rails integration** would be a separate gem (`html2img-rails`), the way
   `html2img-django` sits on top of `html2img-client` in Python. Keep the name
   free.

## When you add or drop a Ruby version

1. Update the matrix in `.github/workflows/ci.yml`.
2. Update `required_ruby_version` in the gemspec if the floor moves. Raising it
   is a major release.
3. Update the badge and the "Requirements" section of the README.
4. Note it in the changelog.

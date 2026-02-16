# Ingress Modernization Design

**Date:** 2026-02-16
**Status:** Approved
**Approach:** Moderate Modernization

## Goals

1. Keep codebase current with modern Ruby practices
2. Prepare foundation for active feature development
3. Improve development experience with better tooling

## Constraints

- Support Ruby 3.3+ only (no backwards compatibility needed)
- Skip CI setup for now (local testing only)
- Use loose dependency constraints for flexibility
- Maintain existing architecture and functionality

## Design

### 1. Ruby Version & Dependencies

**Ruby Version:**
- Update `.ruby-version` to `3.4.5`
- Add `spec.required_ruby_version = ">= 3.3.0"` to gemspec
- Remove `.travis.yml` (outdated CI configuration)

**Dependencies (gemspec):**
- `bundler >= 2.6`
- `rake >= 13.1.0`
- `rspec >= 3.12` (was unversioned)
- `simplecov >= 0.22` (new - test coverage)
- `rubocop >= 1.50` (new - linting)
- `rubocop-rspec >= 2.20` (new - RSpec linting)

All dependencies use `>=` for flexibility in version resolution.

After updating, run `bundle install` to generate `Gemfile.lock`.

### 2. Modernizing Ruby Patterns

**Remove deprecated patterns:**

1. **Coding comments** - Remove `# coding: utf-8` from:
   - `ingress.gemspec`

2. **File path handling** - Replace `File.expand_path` with `__dir__`:
   - `ingress.gemspec`: `File.expand_path('../lib', __FILE__)` → `File.expand_path("lib", __dir__)`
   - `spec/spec_helper.rb`: `File.expand_path('../../lib', __FILE__)` → `File.expand_path("../lib", __dir__)`

3. **Gemspec file listing** - Replace backticks with explicit file list:
   ```ruby
   # Old:
   spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }

   # New:
   spec.files = Dir.glob("lib/**/*") + ["README.md", "LICENSE.txt", "CLAUDE.md"]
   ```

4. **Frozen string literals** - Add `# frozen_string_literal: true` to all lib files:
   - `lib/ingress.rb`
   - `lib/ingress/version.rb`
   - `lib/ingress/permissions.rb`
   - `lib/ingress/permissions_dsl.rb`
   - `lib/ingress/permissions_repository.rb`
   - `lib/ingress/permission_rule.rb`
   - `lib/ingress/build_permissions_repository_for_role.rb`
   - `lib/ingress/copy_permissions_repository_into_role.rb`

### 3. Modern RSpec & Test Coverage

**Enhanced spec_helper.rb:**

```ruby
# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "ingress"

RSpec.configure do |config|
  # Modern expect syntax only
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  # Modern mock syntax
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Better output and test management
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
```

**SimpleCov Integration:**
- Generates coverage reports in `coverage/` directory
- Produces HTML reports for viewing in browser
- Automatically runs with tests

**Update .gitignore:**
- Add `coverage/`
- Add `spec/examples.txt`

### 4. RuboCop Configuration

**Create .rubocop.yml:**

```yaml
require:
  - rubocop-rspec

AllCops:
  TargetRubyVersion: 3.3
  NewCops: enable
  SuggestExtensions: false
  Exclude:
    - 'vendor/**/*'
    - 'script/**/*'

Gemspec/RequiredRubyVersion:
  Enabled: true

Style/Documentation:
  Enabled: false  # We have README

Style/StringLiterals:
  EnforcedStyle: double_quotes

Layout/LineLength:
  Max: 120

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'
    - '*.gemspec'

RSpec/MultipleExpectations:
  Max: 5

RSpec/ExampleLength:
  Max: 15
```

**Initial Application:**
1. Run `bundle exec rubocop -A` to auto-fix safe issues
2. Manually review and fix remaining issues
3. Verify all tests still pass

**Ongoing Usage:**
- Run `bundle exec rubocop` before commits
- Can add to git hooks later if desired

## Implementation Order

1. Update Ruby version and dependencies
2. Modernize Ruby patterns
3. Set up RSpec and SimpleCov
4. Configure and apply RuboCop
5. Run full test suite to verify everything works
6. Commit modernization changes

## Success Criteria

- All tests pass with modern Ruby and dependencies
- Test coverage report generates successfully
- RuboCop runs clean (no offenses)
- Code uses modern Ruby 3.3+ patterns throughout
- Foundation ready for active feature development

## Out of Scope

- CI/CD setup (GitHub Actions, etc.)
- Type signatures (RBS/Sorbet)
- Performance profiling and optimization
- Architectural changes to existing code
- New features or functionality changes

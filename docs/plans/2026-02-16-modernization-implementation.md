# Ingress Modernization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Modernize the Ingress codebase to Ruby 3.3+ with modern tooling and patterns.

**Architecture:** Update Ruby version, dependencies, and patterns while maintaining existing functionality. Add test coverage tracking and linting infrastructure.

**Tech Stack:** Ruby 3.4.5, RSpec 3.12+, SimpleCov, RuboCop

---

## Task 1: Update Ruby Version and Remove Travis CI

**Files:**
- Modify: `.ruby-version`
- Delete: `.travis.yml`

**Step 1: Update Ruby version**

Edit `.ruby-version`:
```
3.4.5
```

**Step 2: Remove Travis CI configuration**

Run: `rm .travis.yml`
Expected: File deleted

**Step 3: Verify Ruby version**

Run: `cat .ruby-version`
Expected: `3.4.5`

**Step 4: Commit**

```bash
git add .ruby-version .travis.yml
git commit -m "chore: update to Ruby 3.4.5 and remove Travis CI"
```

---

## Task 2: Update Gemspec Dependencies

**Files:**
- Modify: `ingress.gemspec`

**Step 1: Add required_ruby_version and update dependencies**

Edit `ingress.gemspec` to add after line 13 (after `spec.license`):

```ruby
  spec.required_ruby_version = ">= 3.3.0"
```

And update the development dependencies section (lines 25-27) to:

```ruby
  spec.add_development_dependency "bundler", ">= 2.6"
  spec.add_development_dependency "rake", ">= 13.1.0"
  spec.add_development_dependency "rspec", ">= 3.12"
  spec.add_development_dependency "simplecov", ">= 0.22"
  spec.add_development_dependency "rubocop", ">= 1.50"
  spec.add_development_dependency "rubocop-rspec", ">= 2.20"
```

**Step 2: Verify changes**

Run: `grep -A 6 'add_development_dependency' ingress.gemspec`
Expected: Shows all 6 dependencies with version constraints

**Step 3: Commit**

```bash
git add ingress.gemspec
git commit -m "chore: add Ruby version requirement and update dependencies"
```

---

## Task 3: Install Dependencies and Verify

**Files:**
- Create: `Gemfile.lock`

**Step 1: Install dependencies**

Run: `bundle install`
Expected: Successfully installs all gems and creates Gemfile.lock

**Step 2: Verify bundle**

Run: `bundle exec ruby -v`
Expected: Shows Ruby 3.4.5

**Step 3: Verify RSpec is available**

Run: `bundle exec rspec --version`
Expected: Shows RSpec 3.12 or higher

**Step 4: Commit Gemfile.lock**

```bash
git add Gemfile.lock
git commit -m "chore: generate Gemfile.lock with updated dependencies"
```

---

## Task 4: Modernize Gemspec Patterns

**Files:**
- Modify: `ingress.gemspec:1-4`
- Modify: `ingress.gemspec:20`

**Step 1: Remove coding comment and update File.expand_path**

In `ingress.gemspec`, replace lines 1-3:

```ruby
# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
```

**Step 2: Update file listing**

Replace line 20 in `ingress.gemspec`:

```ruby
  spec.files = Dir.glob("lib/**/*") + ["README.md", "LICENSE.txt", "CLAUDE.md"]
```

**Step 3: Verify gemspec is valid**

Run: `bundle exec rake build`
Expected: Successfully builds gem file

**Step 4: Commit**

```bash
git add ingress.gemspec
git commit -m "refactor: modernize gemspec with frozen_string_literal and __dir__"
```

---

## Task 5: Update Spec Helper with Modern RSpec Configuration

**Files:**
- Modify: `spec/spec_helper.rb`

**Step 1: Replace spec_helper.rb content**

Replace entire contents of `spec/spec_helper.rb`:

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

**Step 2: Run tests to verify configuration**

Run: `bundle exec rspec`
Expected: Tests run successfully, SimpleCov generates coverage report

**Step 3: Verify coverage directory exists**

Run: `ls -la coverage/`
Expected: Directory exists with index.html and other coverage files

**Step 4: Commit**

```bash
git add spec/spec_helper.rb
git commit -m "feat: add modern RSpec configuration with SimpleCov"
```

---

## Task 6: Add Frozen String Literal to Library Files

**Files:**
- Modify: `lib/ingress.rb:1`
- Modify: `lib/ingress/version.rb:1`
- Modify: `lib/ingress/permissions.rb:1`
- Modify: `lib/ingress/permissions_dsl.rb:1`
- Modify: `lib/ingress/permissions_repository.rb:1`
- Modify: `lib/ingress/permission_rule.rb:1`
- Modify: `lib/ingress/build_permissions_repository_for_role.rb:1`
- Modify: `lib/ingress/copy_permissions_repository_into_role.rb:1`

**Step 1: Add frozen_string_literal to lib/ingress.rb**

Add as first line of `lib/ingress.rb`:
```ruby
# frozen_string_literal: true
```

**Step 2: Add frozen_string_literal to lib/ingress/version.rb**

Add as first line of `lib/ingress/version.rb`:
```ruby
# frozen_string_literal: true
```

**Step 3: Add frozen_string_literal to lib/ingress/permissions.rb**

Add as first line of `lib/ingress/permissions.rb`:
```ruby
# frozen_string_literal: true
```

**Step 4: Add frozen_string_literal to lib/ingress/permissions_dsl.rb**

Add as first line of `lib/ingress/permissions_dsl.rb`:
```ruby
# frozen_string_literal: true
```

**Step 5: Add frozen_string_literal to lib/ingress/permissions_repository.rb**

Add as first line of `lib/ingress/permissions_repository.rb`:
```ruby
# frozen_string_literal: true
```

**Step 6: Add frozen_string_literal to lib/ingress/permission_rule.rb**

Add as first line of `lib/ingress/permission_rule.rb`:
```ruby
# frozen_string_literal: true
```

**Step 7: Add frozen_string_literal to lib/ingress/build_permissions_repository_for_role.rb**

Add as first line of `lib/ingress/build_permissions_repository_for_role.rb`:
```ruby
# frozen_string_literal: true
```

**Step 8: Add frozen_string_literal to lib/ingress/copy_permissions_repository_into_role.rb**

Add as first line of `lib/ingress/copy_permissions_repository_into_role.rb`:
```ruby
# frozen_string_literal: true
```

**Step 9: Run tests to verify**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 10: Commit**

```bash
git add lib/
git commit -m "refactor: add frozen_string_literal to all library files"
```

---

## Task 7: Update .gitignore

**Files:**
- Modify: `.gitignore`

**Step 1: Add coverage and RSpec artifacts to .gitignore**

Append to `.gitignore`:
```
# Test coverage
coverage/

# RSpec status persistence
spec/examples.txt
```

**Step 2: Verify .gitignore**

Run: `tail -5 .gitignore`
Expected: Shows the new entries

**Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: ignore coverage and RSpec artifacts"
```

---

## Task 8: Create RuboCop Configuration

**Files:**
- Create: `.rubocop.yml`

**Step 1: Create .rubocop.yml**

Create `.rubocop.yml`:
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

**Step 2: Verify RuboCop can load configuration**

Run: `bundle exec rubocop --version`
Expected: Shows RuboCop version (1.50+)

**Step 3: Commit**

```bash
git add .rubocop.yml
git commit -m "feat: add RuboCop configuration for modern Ruby style"
```

---

## Task 9: Apply RuboCop Auto-Fixes

**Files:**
- Multiple files may be modified by RuboCop

**Step 1: Run RuboCop with auto-correct**

Run: `bundle exec rubocop -A`
Expected: Auto-fixes safe offenses, shows summary of changes

**Step 2: Review changes**

Run: `git diff`
Expected: Shows automated style fixes

**Step 3: Run tests to ensure nothing broke**

Run: `bundle exec rspec`
Expected: All tests still pass

**Step 4: Commit auto-fixes**

```bash
git add -A
git commit -m "style: apply RuboCop auto-fixes"
```

---

## Task 10: Final Verification

**Files:**
- N/A (verification only)

**Step 1: Run full test suite**

Run: `bundle exec rspec --format documentation`
Expected: All tests pass with detailed output

**Step 2: Check RuboCop status**

Run: `bundle exec rubocop`
Expected: No offenses detected (or only manual-fix offenses remain)

**Step 3: Verify coverage report**

Run: `open coverage/index.html` (or view in browser)
Expected: Coverage report opens showing code coverage percentages

**Step 4: Verify gem can build**

Run: `bundle exec rake build`
Expected: Successfully builds ingress-0.5.1.gem

---

## Task 11: Address Any Remaining RuboCop Offenses (If Needed)

**Files:**
- Varies based on RuboCop output

**Step 1: Check for remaining offenses**

Run: `bundle exec rubocop`
Expected: Shows any remaining offenses that need manual fixes

**Step 2: Fix remaining offenses manually**

Review each offense and fix according to RuboCop suggestions.

**Step 3: Run tests after each fix**

Run: `bundle exec rspec`
Expected: Tests continue to pass

**Step 4: Commit fixes**

```bash
git add -A
git commit -m "style: fix remaining RuboCop offenses"
```

---

## Task 12: Final Summary Commit (If Needed)

**Files:**
- N/A

**Step 1: Check git status**

Run: `git status`
Expected: Clean working tree or only untracked files (coverage/, etc.)

**Step 2: Review commit history**

Run: `git log --oneline -15`
Expected: Shows all modernization commits

**Step 3: Push to experimental branch**

Run: `git push origin experimental`
Expected: All commits pushed successfully

---

## Success Checklist

- [ ] Ruby version updated to 3.4.5
- [ ] All dependencies updated with version constraints
- [ ] Gemfile.lock generated
- [ ] Modern Ruby patterns applied (frozen_string_literal, __dir__)
- [ ] RSpec configured with SimpleCov
- [ ] Coverage report generates successfully
- [ ] RuboCop configured and applied
- [ ] All tests pass
- [ ] Gem builds successfully
- [ ] Changes committed and pushed to experimental branch

## Post-Implementation

After completing this plan:
1. Review the test coverage report to identify any gaps
2. Consider adding additional tests if coverage is low in critical areas
3. Use `bundle exec rubocop` before future commits to maintain code quality
4. The codebase is now ready for active feature development

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ingress is a Ruby gem that provides role-based authorization framework. It's designed as an alternative to CanCan with a key architectural difference: it allows composing permission definitions across multiple smaller classes rather than forcing all permissions into a single monolithic class.

## Development Commands

### Setup
```bash
bundle install
# or
script/setup
```

### Running Tests
```bash
# Run all tests
rake spec
# or
bundle exec rspec

# Run specific test file
bundle exec rspec spec/ingress_spec.rb

# Run tests with documentation format (already configured in .rspec)
bundle exec rspec
```

### Interactive Console
```bash
script/console
```

### Building and Releasing
```bash
# Build gem locally
bundle exec rake install

# Release (requires proper credentials)
bundle exec rake release
```

## Core Architecture

### Key Classes and Their Roles

1. **`Ingress::Permissions`** (lib/ingress/permissions.rb)
   - Base class for all permission definitions
   - Provides `initialize(user)` - all permission objects are instantiated with a user
   - Provides `can?(action, subject, options = {})` - the main authorization check method
   - Requires subclasses to implement `user_role_identifiers` - returns array of role symbols for the user
   - Class methods:
     - `define_role_permissions(role_identifier, permissions_class, &block)` - maps a role to a permission class or defines permissions inline
     - `inherits(permissions_class)` - composes permissions from another class

2. **`PermissionsRepository`** (lib/ingress/permissions_repository.rb)
   - Stores and retrieves permission rules
   - Uses nested hashes for efficient rule lookup: `role -> subject -> action -> rules`
   - `add_permission(role_identifier, allow, action, subject, conditions)` - adds a new rule
   - `rules_for(role_identifier, action, subject)` - retrieves matching rules (handles wildcards)
   - `merge(permission_repository)` - combines multiple repositories
   - `copy_to_role(role_identifier, permission_repository)` - copies rules to a specific role

3. **`PermissionRule`** (lib/ingress/permission_rule.rb)
   - Represents a single permission rule
   - Contains: `action`, `subject`, `conditions` (lambda), `allows` (boolean)
   - `match?(given_action, given_subject, user, options)` - checks if rule applies
   - Handles wildcard matching for actions and subjects
   - Handles class/instance matching for subjects (e.g., `Post` class vs `post` instance)
   - Safely evaluates conditions and logs errors to stderr (or Rails.logger if available)

4. **`PermissionsDsl`** (lib/ingress/permissions_dsl.rb)
   - Provides the DSL for defining permissions
   - `can(actions, subjects, options = {}, &block)` - grants permissions
   - `cannot(actions, subjects, options = {}, &block)` - denies permissions
   - `can_do_anything` - shorthand for `can "*", "*"`
   - Supports three types of conditions:
     - `:if` - general condition lambda
     - `:if_subject_is_an_instance` - condition when subject is an object instance
     - `:if_subject_is_a_class` - condition when subject is a Class/Module
   - All conditions are combined with AND logic

5. **Service Objects**
   - `BuildPermissionsRepositoryForRole` - evaluates a DSL block to build a repository
   - `CopyPermissionsRepositoryIntoRole` - copies a template repository to a specific role

### Permission Resolution Algorithm

When `can?(action, subject)` is called:
1. Iterates through each role identifier for the user
2. For each role, retrieves matching rules from the repository (includes wildcard matches)
3. First checks `cannot` rules - if any match, returns false immediately
4. Then checks `can` rules - if any match, returns true
5. Returns false if no `can` rules match

### Wildcards

- `"*"` can be used for both actions and subjects
- `can "*", Transaction` - can perform any action on Transaction
- `can :update, "*"` - can update any subject
- `can "*", "*"` or `can_do_anything` - can do anything

### Inheritance Pattern

Permission classes can inherit from other permission classes using `inherits`:
```ruby
class LimitedAdminPermissions < Ingress::Permissions
  inherits AdminPermissions  # Gets all AdminPermissions rules

  define_role_permissions do
    cannot :destroy, Comment  # Overrides/restricts inherited permissions
  end
end
```

This allows composition and DRY permission definitions across multiple roles.

## Testing Patterns

- All tests are in `spec/ingress_spec.rb`
- Tests use RSpec with documentation format
- Test structure follows the gem's composition pattern: tests verify permission inheritance, role composition, and condition evaluation

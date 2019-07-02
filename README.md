# Ingress

A simple role based authorization framework inspired by CanCan (similar syntax) with a nicer interface for defining the permissions for the roles in your system.

The biggest problem I had with CanCan was the fact that it mostly forced you define the permissions for all the roles in one class (really one method). And when the set of permissions in your system grew very large, you had to bend over backwards to allow you to break things down.

In the OO world we're used to being able to break down functionality into multiple smaller classes which we can them compose into a greater whole. This is the main idea behind this gem, keep the nice syntax that CanCan had, but allow composing the main permission object in your system from many smaller classes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ingress'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ingress

## Usage

Let's say you have a user object in your system and the user can have multiple roles. Our set of roles will be `guest`, `member`, `admin`.

First we create the main permission object in our system, let's call it `UserPermissions`:

```ruby
class UserPermissions < Ingress::Permissions
  def user_role_identifiers
    user.roles.map do |role|
      role.name.to_sym
    end
  end
end
```

A couple of things of note is that it inherits from `Ingress::Permissions`, from which it inherits the initializer:

```ruby
attr_reader :user

def initialize(user)
  @user = user
end
```

So this object is always instantiated with a user. The second thing to note is that we have to provide a method called
`user_role_identifiers` which needs to return a list of role identifier that this particular user has. Above we make the
assumptions that a user has many roles and that a role has a name. So we iterate over the roles collect the symbolized names
and return them. This is essentially what ties everything together. We haven't defined any permissions just yet, but we
can already do the following:

```ruby
user_permissions = UserPermissions.new(user)
user_permissions.can?(:do, :stuff) # returns false
```

So now we have an object that we can instantiate anywhere, and ask it if our user has a particular permission.
Let us now define some permissions for a role. We'll start with the guest role. First, let's update our `UserPermissions`
object:

```ruby
class UserPermissions < Ingress::Permissions
  define_role_permissions :guest, GuestPermissions

  def user_role_identifiers
    user.roles.map do |role|
      role.name.to_sym
    end
  end
end
```

We've now said that the permission for the role with the `guest` identifier live in the `GuestPermissions` class. Let's create
it:

```ruby
class GuestPermissions < Ingress::Permissions
  define_role_permissions do
    can :view, :non_sensitive_info
    can [:create], :session
  end
end
```

It's pretty self explanatory, the class again inherits from `Ingress::Permissions` as that's where the simple DSL for defining
permissions lives. The thing to note is that we called the class `GuestPermissions`, but it could be called anything, the permissions
we define here are not attached to any role. They only get attached to the role via the `define_role_permissions :guest, GuestPermissions`
line in the `UserPermissions` class. The syntax for defining permissions is:

```
can 'action', 'subject'
or
cannot 'action', 'subject'
```

Similar to CanCan, the `action` can be any string, symbol or array of strings or symbols. The `subject` can also be a string or symbol, or
it can be a class constant. Let's define permissions for the next role in our system, `member` which is more complex. Firstly, update our `UserPermissions`.

```ruby
class UserPermissions < Ingress::Permissions
  define_role_permissions :guest, GuestPermissions
  define_role_permissions :member, MemberPermissions

  def user_role_identifiers
    user.roles.map do |role|
      role.name.to_sym
    end
  end
end
```

Simple, next `MemberPermissions` class:

```ruby
class MemberPermissions < Ingress::Permissions
  define_role_permissions do
    can [:show, :update, :destroy], :session
    can :accept, :terms
    can [:view, :create], Post
    can [:update, :destroy], Post, if: ->(user, post) do
      user.id == post.user_id
    end
  end
end
```

It's a little bit more complex, but still fairly self explanatory. As you can see, we have a `Post` object in our system. So we allow
user with a `member` role to view and create posts, and they can update and destroy posts that they own. So we could do:

```ruby
user_permissions = UserPermissions.new(user)
user_permissions.can?(:create, Post) # returns true
post = user.posts.first # assume we can get the list of posts form the user object
user_permissions.can?(:update, post) # returns true
```

The condition lambda always takes two parameters, the `user` and an `object`, the object is whatever we supply to the `can?` method,
when we check permissions.

Let's add our admin role:

```ruby
class UserPermissions < Ingress::Permissions
  define_role_permissions :guest, GuestPermissions
  define_role_permissions :member, MemberPermissions
  define_role_permissions :admin, AdminPermissions

  def user_role_identifiers
    user.roles.map do |role|
      role.name.to_sym
    end
  end
end
```

And the class:

```ruby
class AdminPermissions < Ingress::Permissions
  define_role_permissions do
    can "*", "*" # you can also use can_do_anything
  end
end
```

As you can see both `action` and `subject` can be wildcards, so in this case an admin would be able to do anything in the system, i.e.
any call to `can?` will always return `true`.

So what else can we do? Well let's say we wanted another role called `limited_admin` which would be similar to admin, but can't destroy
comments:

```ruby
class UserPermissions < Ingress::Permissions
  define_role_permissions :guest, GuestPermissions
  define_role_permissions :member, MemberPermissions
  define_role_permissions :admin, AdminPermissions
  define_role_permissions :limited_admin, LimitedAdminPermissions

  def user_role_identifiers
    user.roles.map do |role|
      role.name.to_sym
    end
  end
end
```

And the class:

```ruby
class LimitedAdminPermissions < Ingress::Permissions
  inherits AdminPermissions

  define_role_permissions do
    cannot :destroy, Comment
  end
end
```

So basically, we can inherit permissions that are defined in other classes, and either switch off some or add others. Let's create
some sort of `super_member` role, which can do everything a member can do, but can also update anything in the system:

```ruby
class UserPermissions < Ingress::Permissions
  define_role_permissions :guest, GuestPermissions
  define_role_permissions :member, MemberPermissions
  define_role_permissions :admin, AdminPermissions
  define_role_permissions :limited_admin, LimitedAdminPermissions
  define_role_permissions :super_member, SuperMemberPermissions

  def user_role_identifiers
    user.roles.map do |role|
      role.name.to_sym
    end
  end
end
```

And the class:

```ruby
class SuperMemberPermissions < Ingress::Permissions
  inherits MemberPermissions

  define_role_permissions do
    can :update, "*"
  end
end
```

We can inherit permissions, and we use a wildcard subject, to allow a user with the `super_member` role to be able to update anything. We
can even define a common set of permissions which we want multiple roles to share and have the permission class for each of those roles
inherit from the common set. Let's say we want a `financial_officer` role and a `reporting_officer` role both of which should have the ability to do anything with a `Transaction` object in our system (for whatever reason):

```ruby
class UserPermissions < Ingress::Permissions
  define_role_permissions :guest, GuestPermissions
  define_role_permissions :member, MemberPermissions
  define_role_permissions :admin, AdminPermissions
  define_role_permissions :limited_admin, LimitedAdminPermissions
  define_role_permissions :super_member, SuperMemberPermissions
  define_role_permissions :financial_officer, FinancialOfficerPermissions
  define_role_permissions :reporting_officer, ReportingOfficerPermissions

  def user_role_identifiers
    user.roles.map do |role|
      role.name.to_sym
    end
  end
end
```

And the classes:

```ruby
class CommonPermissions < Ingress::Permissions
  define_role_permissions do
    can "*", Transaction
  end
end

class FinancialOfficerPermissions < Ingress::Permissions
  inherits CommonPermissions
end

class ReportingOfficerPermissions < Ingress::Permissions
  inherits CommonPermissions
end
```

Now we wildcard the action, so we can do anything to `Transaction` objects. And we have to other sets of permission inherit from
the `CommonPermissions` class.

I hope it's relatively clear that it's pretty flexible, you can almost endlessly decompose the permission definitions into smaller classes
then combine via `inherits` and assign the final permission set to a role identifier via `define_role_permissions` on the main
`UserPermissions` class.

So now the authorization in your system can be defined in a much more OO way, without nasty and complex tricks. And you can still enjoy a nice syntax very similar to CanCan.

This framework has no hooks into Rails (these would be trivial to write if necessary, e.g. you can instantiate the `user_permissions` object on your `ApplicationController` and then do the `can?` checks anywhere you want) and can therefore be used with any web framework, or even outside of the context of a web framework (if such a use case makes sense).

## Development

After checking out the repo, run `script/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `script/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/skorks/ingress.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

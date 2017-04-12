require "spec_helper"

# basically a set of functional tests for the permission library
RSpec.describe Ingress do
  # a test 'model', you can create a TestBlogPost owned by a user
  class TestBlogPost
    attr_reader :id, :user_id

    def initialize(id: nil, user_id: nil)
      @id = id
      @user_id = user_id
    end
  end

  # a test 'user', you can create a TestUser with particular roles
  class TestUser
    attr_reader :id, :role_identifiers

    def initialize(id: nil, role_identifiers: [])
      @id = id
      @role_identifiers = role_identifiers
    end
  end

  class MemberPermissions < Ingress::Permissions
    define_role_permissions do
      can :create, :member_stuff

      can :create, TestBlogPost
      can :destroy, TestBlogPost

      can :update, TestBlogPost, if: -> (user, blog_post) { user.id == blog_post.user_id }
    end
  end

  class DudePermissions < Ingress::Permissions
    define_role_permissions do
      can :create, :dude_stuff
    end
  end

  class SpecialMemberPermissions < Ingress::Permissions
    inherits MemberPermissions

    define_role_permissions do
      can :locate, TestBlogPost
      cannot :create, :member_stuff
    end
  end

  class AdminPermissions < Ingress::Permissions
    define_role_permissions do
      can "*", "*"
    end
  end

  class SpecialAdminPermissions < Ingress::Permissions
    inherits AdminPermissions

    define_role_permissions do
      cannot :create, :wodget
    end
  end

  class CookerPermissions < Ingress::Permissions
    define_role_permissions do
      can :cook, "*"

      can :badly_cook, "*", if: -> (user, record) { record == TestBlogPost || record.kind_of?(TestBlogPost) }
    end
  end

  class CleanerPermissions < Ingress::Permissions
    define_role_permissions do
      can "*", :wodget

      can "*", TestBlogPost, if: -> (user, record) { record.kind_of?(TestBlogPost) && record.id == 5 }

      can "*", :with_if_style, if: -> (user, record) { record.kind_of?(TestBlogPost) && record.id == 5 }
      can "*", :with_block do |user, record|
        record.kind_of?(TestBlogPost) && record.id == 5
      end
    end
  end

  class TestUserPermissions < Ingress::Permissions
    define_role_permissions :member, MemberPermissions
    define_role_permissions :dude, DudePermissions
    define_role_permissions :special_member, SpecialMemberPermissions
    define_role_permissions :admin, AdminPermissions
    define_role_permissions :special_admin, SpecialAdminPermissions
    define_role_permissions :cooker, CookerPermissions
    define_role_permissions :cleaner, CleanerPermissions

    def user_role_identifiers
      user.role_identifiers
    end
  end

  describe "when user has no role" do
    let(:user) { TestUser.new(id: 5, role_identifiers: []) }
    let(:permissions) { TestUserPermissions.new(user) }

    it "user is not able to do things not defined for role" do
      expect(permissions.can?(:create, :member_stuff)).to be_falsy
    end
  end

  describe "when user has single role" do
    let(:user) { TestUser.new(id: 5, role_identifiers: [:member]) }
    let(:permissions) { TestUserPermissions.new(user) }

    it "user is able to do basic action defined for role" do
      expect(permissions.can?(:create, :member_stuff)).to be_truthy
    end

    it "user is not able to things not defined for role" do
      expect(permissions.can?(:show, :member_stuff)).to be_falsy
    end

    context "for permissions defined with class" do
      let(:blog_post) { TestBlogPost.new }

      it "user is able to do basic action defined for role" do
        expect(permissions.can?(:create, blog_post)).to be_truthy
        expect(permissions.can?(:destroy, blog_post)).to be_truthy
      end
    end

    context "for permissions defined with class with conditions" do
      let(:blog_post) { TestBlogPost.new }

      context "when conditions won't match" do
        let(:user) { TestUser.new(id: 5, role_identifiers: [:member]) }
        let(:blog_post) { TestBlogPost.new(id: 88, user_id: 4) }

        it "user is not able to do action defined for role" do
          expect(permissions.can?(:update, blog_post)).to be_falsy
        end
      end

      context "when conditions will match" do
        let(:user) { TestUser.new(id: 5, role_identifiers: [:member]) }
        let(:blog_post) { TestBlogPost.new(id: 88, user_id: 5) }

        it "user is able to do action defined for role" do
          expect(permissions.can?(:update, blog_post)).to be_truthy
        end
      end

      context "when class is given instead of instance" do
        it "should fail but shouldn't error" do
          expect(permissions.can?(:update, TestBlogPost)).to be_falsy
        end
      end
    end
  end

  describe "when user has 2 roles that have permissions defined for them" do
    let(:user) { TestUser.new(id: 5, role_identifiers: [:member, :dude]) }
    let(:permissions) { TestUserPermissions.new(user) }

    it "user is able to do things defined in both roles" do
      expect(permissions.can?(:create, :member_stuff)).to be_truthy
      expect(permissions.can?(:create, :dude_stuff)).to be_truthy
    end
  end

  describe "when user has role that inherits all permissions from antoher role" do
    let(:user) { TestUser.new(id: 5, role_identifiers: [:special_member]) }
    let(:permissions) { TestUserPermissions.new(user) }
    let(:blog_post) { TestBlogPost.new }

    it "user is able to do basic action defined for role" do
      expect(permissions.can?(:create, blog_post)).to be_truthy
    end

    it "user is able to do things defined only for the new role" do
      expect(permissions.can?(:locate, blog_post)).to be_truthy
    end

    it "user is not able to do things that are taken away for the new role" do
      expect(permissions.can?(:create, :member_stuff)).to be_falsy
    end

    context "and user has 2 roles and one has permissions that are taken away by another" do
      let(:user) { TestUser.new(id: 5, role_identifiers: [:member, :special_member]) }

      it "user is able to do things that are taken away by one of the roles" do
        expect(permissions.can?(:create, :member_stuff)).to be_truthy
      end
    end
  end

  describe "when user has role that role allows everything" do
    let(:user) { TestUser.new(id: 5, role_identifiers: [:admin]) }
    let(:permissions) { TestUserPermissions.new(user) }
    let(:blog_post) { TestBlogPost.new }

    it "user is able to do anything" do
      expect(permissions.can?(:foobar, :wodget)).to be_truthy
      expect(permissions.can?(:create, blog_post)).to be_truthy
    end
  end

  describe "when user has role which inherits from a role that allows everything and takes away a permission" do
    let(:user) { TestUser.new(id: 5, role_identifiers: [:special_admin]) }
    let(:permissions) { TestUserPermissions.new(user) }
    let(:blog_post) { TestBlogPost.new }

    it "user is not able to do the thing that was taken away" do
      expect(permissions.can?(:create, :wodget)).to be_falsy
    end

    it "user is able to do anything else" do
      expect(permissions.can?(:foobar, :wodget)).to be_truthy
      expect(permissions.can?(:create, blog_post)).to be_truthy
    end
  end

  describe "when user has role that allows a specific action on anything" do
    let(:user) { TestUser.new(id: 5, role_identifiers: [:cooker]) }
    let(:permissions) { TestUserPermissions.new(user) }
    let(:blog_post) { TestBlogPost.new }

    it "user is able to do that action on anything" do
      expect(permissions.can?(:cook, :wodget)).to be_truthy
      expect(permissions.can?(:cook, blog_post)).to be_truthy
    end

    it "user is not able to do another action on anything" do
      expect(permissions.can?(:foo, :wodget)).to be_falsy
    end

    context "with a condition" do
      it "user is able to do that action on anything where the condition is met" do
        expect(permissions.can?(:badly_cook, TestBlogPost)).to be_truthy
        expect(permissions.can?(:badly_cook, blog_post)).to be_truthy
      end

      it "user is not able to do that action on things where the condition is not met" do
        expect(permissions.can?(:badly_cook, :wodget)).to be_falsy
      end
    end
  end

  describe "when user has role that allows any action on a specific thing" do
    let(:user) { TestUser.new(id: 5, role_identifiers: [:cleaner]) }
    let(:permissions) { TestUserPermissions.new(user) }
    let(:blog_post) { TestBlogPost.new }

    it "user is able to do any action on that thing" do
      expect(permissions.can?(:foo, :wodget)).to be_truthy
      expect(permissions.can?(:bar, :wodget)).to be_truthy
    end

    it "user is not able to do any action on another thing" do
      expect(permissions.can?(:foo, :bazzer)).to be_falsy
    end

    context "with a condition" do
      it "user is able to do any action on a thing where the condition is met" do
        expect(permissions.can?(:foo, TestBlogPost.new(id: 5))).to be_truthy
        expect(permissions.can?(:bar, TestBlogPost.new(id: 5))).to be_truthy
      end

      it "user is not able to do any action on a thing where the condition is not met" do
        expect(permissions.can?(:foo, TestBlogPost.new(id: 4))).to be_falsy
      end
    end

    context "differing styles of defining conditions" do
      it "permits when defined with an if: condition" do
        expect(permissions.can?(:with_if_style, TestBlogPost.new(id: 5))).to be_truthy
      end

      it "permits when defined with a block condition" do
        expect(permissions.can?(:with_block, TestBlogPost.new(id: 5))).to be_truthy
      end

      it "denies when defined with an if: condition" do
        expect(permissions.can?(:with_if_style, TestBlogPost.new(id: 4))).to be_falsy
      end

      it "denies when defined with a block condition" do
        expect(permissions.can?(:with_block, TestBlogPost.new(id: 4))).to be_falsy
      end
    end
  end
end

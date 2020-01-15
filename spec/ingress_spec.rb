require "spec_helper"
require "securerandom"

RSpec.describe Ingress do
  class TestUser
    attr_reader :id, :role_identifiers, :disabled

    def initialize(id: nil, role_identifiers: [], disabled: false)
      @id = id
      @role_identifiers = role_identifiers
      @disabled = disabled
    end
  end

  class TestObject
    attr_reader :id, :user_id, :read_only

    def initialize(id: nil, user_id: nil, read_only: false)
      @id = id
      @user_id = user_id
      @read_only = read_only
    end
  end

  describe "when user has no role", uuid: SecureRandom.uuid do
    let(:user_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions(:member) do
          can "*", "*"
        end

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 5, role_identifiers: []) }
    let(:permissions) { user_permissions_class.new(user) }

    it "user is not able to do anything" do
      expect(permissions.can?(:create, :member_stuff)).to be_falsy
    end
  end

  describe "when user has single role" do
    let(:member_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions do
          can :create, :member_stuff

          can :create, TestObject
          can :destroy, TestObject

          can :update, TestObject, if: -> (user, object) { user.id == object.user_id }
          cannot %i[update destroy], TestObject, if: -> (user, object) { object.read_only }
          cannot '*', '*', if: -> (user, _object) { user.disabled }
        end
      end
    end
    let(:user_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions :member, MemberPermissions

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 5, role_identifiers: [:member]) }
    let(:permissions) { user_permissions_class.new(user) }

    before do
      MemberPermissions = member_permissions_class
    end

    after do
      Object.send(:remove_const, :MemberPermissions)
    end

    it "user is able to do basic action defined for role" do
      expect(permissions.can?(:create, :member_stuff)).to be_truthy
    end

    it "user is not able to things not defined for role" do
      expect(permissions.can?(:show, :member_stuff)).to be_falsy
    end

    context "for permissions defined with class" do
      let(:test_object) { TestObject.new }

      it "user is able to do basic action defined for role" do
        expect(permissions.can?(:create, test_object)).to be_truthy
        expect(permissions.can?(:destroy, test_object)).to be_truthy
      end
    end

    context "for permissions defined with class with conditions" do
      let(:test_object) { TestObject.new }

      context "when conditions won't match" do
        let(:user) { TestUser.new(id: 5, role_identifiers: [:member]) }
        let(:test_object) { TestObject.new(id: 88, user_id: 4) }

        it "user is not able to do action defined for role" do
          expect(permissions.can?(:update, test_object)).to be_falsy
        end
      end

      context "when conditions will match" do
        let(:user) { TestUser.new(id: 5, role_identifiers: [:member]) }
        let(:test_object) { TestObject.new(id: 88, user_id: 5) }

        it "user is able to do action defined for role", :aggregate_failures do
          expect(permissions.can?(:update, test_object)).to be_truthy
          expect(permissions.can?(:create, :member_stuff)).to be_truthy
          expect(permissions.can?(:create, TestObject)).to be_truthy
        end
      end

      context "when cannot conditions will match" do
        let(:user) { TestUser.new(id: 5, role_identifiers: [:member], disabled: true) }
        let(:test_object) { TestObject.new(id: 88, user_id: 5, read_only: true) }

        it "user is not able to do action defined for role", :aggregate_failures do
          expect(permissions.can?(:update, test_object)).to be_falsy
          expect(permissions.can?(:create, :member_stuff)).to be_falsy
          expect(permissions.can?(:create, TestObject)).to be_falsy
        end
      end

      context "when class is given instead of instance" do
        it "should fail but shouldn't error" do
          expect(permissions.can?(:update, TestObject)).to be_falsy
        end
      end
    end
  end

  describe "when user has 2 roles that have permissions defined for them" do
    let(:member_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions do
          can :create, :member_stuff
        end
      end
    end
    let(:subscriber_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions do
          can :create, :subscriber_stuff
        end
      end
    end
    let(:user_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions :member, MemberPermissions
        define_role_permissions :subscriber, SubscriberPermissions

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 5, role_identifiers: [:member, :subscriber]) }
    let(:permissions) { user_permissions_class.new(user) }

    before do
      MemberPermissions = member_permissions_class
      SubscriberPermissions = subscriber_permissions_class
    end

    after do
      Object.send(:remove_const, :MemberPermissions)
      Object.send(:remove_const, :SubscriberPermissions)
    end

    it "user is able to do things defined in both roles" do
      expect(permissions.can?(:create, :member_stuff)).to be_truthy
      expect(permissions.can?(:create, :subscriber_stuff)).to be_truthy
    end
  end

  describe "when user has role that inherits all permissions from another role" do
    let(:member_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions do
          can :create, :member_stuff
          can :create, TestObject
        end
      end
    end
    let(:special_member_permissions_class) do
      Class.new(Ingress::Permissions) do
        inherits MemberPermissions

        define_role_permissions do
          can :locate, TestObject
          cannot :create, :member_stuff
        end
      end
    end
    let(:user_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions :member, MemberPermissions
        define_role_permissions :special_member, SpecialMemberPermissions

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 5, role_identifiers: [:special_member]) }
    let(:permissions) { user_permissions_class.new(user) }
    let(:test_object) { TestObject.new }

    before do
      MemberPermissions = member_permissions_class
      SpecialMemberPermissions = special_member_permissions_class
    end

    after do
      Object.send(:remove_const, :MemberPermissions)
      Object.send(:remove_const, :SpecialMemberPermissions)
    end

    it "user is able to do basic action defined for role" do
      expect(permissions.can?(:create, test_object)).to be_truthy
    end

    it "user is able to do things defined only for the new role" do
      expect(permissions.can?(:locate, test_object)).to be_truthy
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
    let(:admin_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions do
          can "*", "*"
        end
      end
    end
    let(:user_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions :admin, AdminPermissions

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 5, role_identifiers: [:admin]) }
    let(:permissions) { user_permissions_class.new(user) }
    let(:test_object) { TestObject.new }

    before do
      AdminPermissions = admin_permissions_class
    end

    after do
      Object.send(:remove_const, :AdminPermissions)
    end

    it "user is able to do anything" do
      expect(permissions.can?(:foobar, :wodget)).to be_truthy
      expect(permissions.can?(:create, test_object)).to be_truthy
    end
  end

  describe "when user has role which inherits from a role that allows everything and takes away a permission" do
    let(:admin_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions do
          can "*", "*"
        end
      end
    end
    let(:limited_admin_permissions_class) do
      Class.new(Ingress::Permissions) do
        inherits AdminPermissions

        define_role_permissions do
          cannot :create, :wodget
        end
      end
    end
    let(:user_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions :admin, AdminPermissions
        define_role_permissions :limited_admin, LimitedAdminPermissions

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 5, role_identifiers: [:limited_admin]) }
    let(:permissions) { user_permissions_class.new(user) }
    let(:test_object) { TestObject.new }

    before do
      AdminPermissions = admin_permissions_class
      LimitedAdminPermissions = limited_admin_permissions_class
    end

    after do
      Object.send(:remove_const, :AdminPermissions)
      Object.send(:remove_const, :LimitedAdminPermissions)
    end

    it "user is not able to do the thing that was taken away" do
      expect(permissions.can?(:create, :wodget)).to be_falsy
    end

    it "user is able to do anything else" do
      expect(permissions.can?(:foobar, :wodget)).to be_truthy
      expect(permissions.can?(:create, test_object)).to be_truthy
    end
  end

  describe "when user has role that allows a specific action on anything" do
    let(:member_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions do
          can :create, "*"
          can :destroy, "*", if: -> (user, record) { record == TestObject || record.kind_of?(TestObject) }
        end
      end
    end
    let(:user_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions :member, MemberPermissions

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 5, role_identifiers: [:member]) }
    let(:permissions) { user_permissions_class.new(user) }
    let(:test_object) { TestObject.new }

    before do
      MemberPermissions = member_permissions_class
    end

    after do
      Object.send(:remove_const, :MemberPermissions)
    end

    it "user is able to do that action on anything" do
      expect(permissions.can?(:create, :wodget)).to be_truthy
      expect(permissions.can?(:create, test_object)).to be_truthy
    end

    it "user is not able to do another action on anything" do
      expect(permissions.can?(:foo, :wodget)).to be_falsy
    end

    context "with a condition" do
      it "user is able to do that action on anything where the condition is met" do
        expect(permissions.can?(:destroy, TestObject)).to be_truthy
        expect(permissions.can?(:destroy, test_object)).to be_truthy
      end

      it "user is not able to do that action on things where the condition is not met" do
        expect(permissions.can?(:destroy, :wodget)).to be_falsy
      end
    end
  end

  describe "when user has role that allows any action on a specific thing" do
    let(:member_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions do
          can "*", :wodget

          can "*", TestObject, if: -> (user, record) { record.kind_of?(TestObject) && record.id == 5 }

          can "*", :with_if_style, if: -> (user, record) { record.kind_of?(TestObject) && record.id == 5 }
          can "*", :with_block do |user, record|
            record.kind_of?(TestObject) && record.id == 5
          end
        end
      end
    end
    let(:user_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions :member, MemberPermissions

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 5, role_identifiers: [:member]) }
    let(:permissions) { user_permissions_class.new(user) }
    let(:test_object) { TestObject.new }

    before do
      MemberPermissions = member_permissions_class
    end

    after do
      Object.send(:remove_const, :MemberPermissions)
    end

    it "user is able to do any action on that thing" do
      expect(permissions.can?(:foo, :wodget)).to be_truthy
      expect(permissions.can?(:bar, :wodget)).to be_truthy
    end

    it "user is not able to do any action on another thing" do
      expect(permissions.can?(:foo, :bazzer)).to be_falsy
    end

    context "with a condition" do
      it "user is able to do any action on a thing where the condition is met" do
        expect(permissions.can?(:foo, TestObject.new(id: 5))).to be_truthy
        expect(permissions.can?(:bar, TestObject.new(id: 5))).to be_truthy
      end

      it "user is not able to do any action on a thing where the condition is not met" do
        expect(permissions.can?(:foo, TestObject.new(id: 4))).to be_falsy
      end

      it "should be able to do action if Class is provided" do
        expect(permissions.can?(:with_block, TestObject)).to be_truthy
      end

    end

    context "differing styles of defining conditions" do
      it "permits when defined with an if: condition" do
        expect(permissions.can?(:with_if_style, TestObject.new(id: 5))).to be_truthy
      end

      it "permits when defined with a block condition" do
        expect(permissions.can?(:with_block, TestObject.new(id: 5))).to be_truthy
      end

      it "denies when defined with an if: condition" do
        expect(permissions.can?(:with_if_style, TestObject.new(id: 4))).to be_falsy
      end

      it "denies when defined with a block condition" do
        expect(permissions.can?(:with_block, TestObject.new(id: 4))).to be_falsy
      end
    end
  end
end

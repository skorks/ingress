# frozen_string_literal: true

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

          can :update, TestObject, if: ->(user, object) { user.id == object.user_id unless object.is_a?(Class) }
          cannot %i[update destroy], TestObject, if: ->(_user, object) { object.read_only unless object.is_a?(Class) }
          cannot "*", "*", if: ->(user, _object) { user.disabled }
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
    let(:user) { TestUser.new(id: 5, role_identifiers: %i[member subscriber]) }
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
      let(:user) { TestUser.new(id: 5, role_identifiers: %i[member special_member]) }

      it "user is able to do things that are taken away by one of the roles" do
        expect(permissions.can?(:create, :member_stuff)).to be_truthy
      end
    end
  end

  describe "when inherits is called with nil" do
    it "does not raise an error" do
      expect {
        Class.new(Ingress::Permissions) do
          inherits nil
          define_role_permissions { can :action, :subject }
        end
      }.not_to raise_error
    end

    it "still allows permissions to be defined" do
      permissions_class = Class.new(Ingress::Permissions) do
        inherits nil
        define_role_permissions(:member) { can :action, :subject }

        def user_role_identifiers
          [:member]
        end
      end

      user = TestUser.new(id: 1)
      permissions = permissions_class.new(user)
      expect(permissions.can?(:action, :subject)).to be true
    end
  end

  describe "when using deeply nested arrays in DSL" do
    let(:permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions(:member) do
          can [[[:read, :write]], :delete], :posts
          can :update, [[:comments, :likes]]
        end

        def user_role_identifiers
          [:member]
        end
      end
    end
    let(:user) { TestUser.new(id: 1) }
    let(:permissions) { permissions_class.new(user) }

    it "flattens nested action arrays properly" do
      expect(permissions.can?(:read, :posts)).to be true
      expect(permissions.can?(:write, :posts)).to be true
      expect(permissions.can?(:delete, :posts)).to be true
    end

    it "flattens nested subject arrays properly" do
      expect(permissions.can?(:update, :comments)).to be true
      expect(permissions.can?(:update, :likes)).to be true
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
          can :destroy, "*", if: ->(_user, record) { record == TestObject || record.is_a?(TestObject) }
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

          can :foo, TestObject, if: lambda { |_user, given_subject|
            given_subject.is_a?(TestObject) ? (given_subject.id == 5) : true
          }

          can :bar, TestObject, if_subject_is_an_instance: lambda { |_user, object, _option|
            object.id == 5
          }

          can :baz, TestObject, if_subject_is_a_class: lambda { |_user, _klass, option|
            option[:id] == 9
          }

          can :foo_bar_baz, TestObject,
              if: lambda { |_user, given_subject|
                given_subject.is_a?(TestObject) ? (given_subject.id == 5) : true
              },
              if_subject_is_an_instance: lambda { |_user, _object, option|
                option[:id] == 5
              },
              if_subject_is_a_class: lambda { |_user, _klass, option|
                option[:id] == 9
              }

          can "*", :with_if_style, if: ->(_user, _action, record) { record.is_a?(TestObject) && record.id == 5 }
          can "*", :with_block do |_user, _action, record|
            record.is_a?(TestObject) && record.id == 5
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

    context "with the 'if:' condition" do
      it "user is able to do any action on a thing where the condition is met" do
        expect(permissions.can?(:foo, TestObject.new(id: 5))).to be_truthy
      end

      it "user is not able to do any action on a thing where the condition is not met" do
        expect(permissions.can?(:foo, TestObject.new(id: 4))).to be_falsy
      end

      it "should be able to do action if Class is provided" do
        expect(permissions.can?(:foo, TestObject)).to be_truthy
      end
    end

    context "with the 'if_subject_is_an_instance:' condition" do
      it "user is able to do any action on a thing where the condition is met" do
        expect(permissions.can?(:bar, TestObject.new(id: 5))).to be_truthy
      end

      it "user is not able to do any action on a thing where the condition is not met" do
        expect(permissions.can?(:bar, TestObject.new(id: 4))).to be_falsy
      end

      it "user is able to do any action if Class is provided" do
        expect(permissions.can?(:bar, TestObject)).to be_truthy
      end
    end

    context "with the 'if_subject_is_a_class:' condition" do
      it "user is able to do any action on a thing where the condition is met" do
        expect(permissions.can?(:baz, TestObject, { id: 9 })).to be_truthy
      end

      it "user is not able to do any action on a thing where the condition is not met" do
        expect(permissions.can?(:baz, TestObject, { id: 4 })).to be_falsy
      end

      it "user is able to do any action if an instance is provided" do
        expect(permissions.can?(:baz, TestObject.new(id: 9))).to be_truthy
      end
    end

    context "with the all the conditions combined" do
      context "when all the conditions are not met" do
        it "user is able to do any action on a thing where the condition is met" do
          expect(permissions.can?(:foo_bar_baz, TestObject.new(id: 5), { id: 5 })).to be_truthy
          expect(permissions.can?(:foo_bar_baz, TestObject, { id: 9 })).to be_truthy
        end
      end

      context "when the 'if:' condition is not met" do
        it "user is able not to do any action on a thing" do
          expect(permissions.can?(:foo_bar_baz, TestObject.new(id: 9), { id: 5 })).to be_falsy
        end
      end

      context "when the 'if_subject_is_an_instance:' condition is not met" do
        it "user is able not to do any action on a thing" do
          expect(permissions.can?(:foo_bar_baz, TestObject.new(id: 5), { id: 9 })).to be_falsy
        end
      end

      context "when the 'if_subject_is_a_class:' condition is not met" do
        it "user is able not to do any action on a thing" do
          expect(permissions.can?(:foo_bar_baz, TestObject, { id: 10 })).to be_falsy
        end
      end
    end

    context "differing styles of defining conditions" do
      it "permits when defined with an if: condition" do
        expect(permissions.can?(:foo, :with_if_style, TestObject.new(id: 5))).to be_truthy
      end

      it "permits when defined with a block condition" do
        expect(permissions.can?(:foo, :with_block, TestObject.new(id: 5))).to be_truthy
      end

      it "denies when defined with an if: condition" do
        expect(permissions.can?(:foo, :with_if_style, TestObject.new(id: 4))).to be_falsy
      end

      it "denies when defined with a block condition" do
        expect(permissions.can?(:foo, :with_block, TestObject.new(id: 4))).to be_falsy
      end
    end
  end

  describe "when condition raises an exception" do
    let(:error_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions(:member) do
          can :action, :subject, if: ->(_user, _subject) { raise StandardError, "Condition error" }
        end

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 1, role_identifiers: [:member]) }
    let(:permissions) { error_permissions_class.new(user) }

    it "returns false when condition raises exception" do
      # Suppress stderr output during test
      allow($stderr).to receive(:write)
      expect(permissions.can?(:action, :subject)).to be false
    end

    it "does not raise the exception to the caller" do
      # Suppress stderr output during test
      allow($stderr).to receive(:write)
      expect { permissions.can?(:action, :subject) }.not_to raise_error
    end

    it "logs error message to stderr" do
      expect { permissions.can?(:action, :subject) }.to output(/Condition error/).to_stderr
    end
  end

  describe "when condition uses variable arity lambda" do
    let(:varargs_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions(:member) do
          can :action, :subject, if: ->(*args) { args.size >= 2 }
        end

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 1, role_identifiers: [:member]) }
    let(:permissions) { varargs_permissions_class.new(user) }

    it "handles variable arity conditions correctly" do
      expect(permissions.can?(:action, :subject)).to be true
    end

    it "receives user and subject arguments" do
      # Variable arity lambda with arity -1 should work
      received_args = nil
      permissions_class = Class.new(Ingress::Permissions) do
        define_role_permissions(:member) do
          can :action, :subject, if: ->(*args) { received_args = args; true }
        end

        def user_role_identifiers
          user.role_identifiers
        end
      end

      test_permissions = permissions_class.new(user)
      test_permissions.can?(:action, :subject)
      expect(received_args).not_to be_nil
      expect(received_args.size).to be >= 2
    end
  end

  describe "can_do_anything helper" do
    let(:admin_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions(:admin) do
          can_do_anything
        end

        def user_role_identifiers
          user.role_identifiers
        end
      end
    end
    let(:user) { TestUser.new(id: 1, role_identifiers: [:admin]) }
    let(:permissions) { admin_permissions_class.new(user) }

    it "is equivalent to wildcards for any action" do
      expect(permissions.can?(:create, :anything)).to be true
      expect(permissions.can?(:read, :anything)).to be true
      expect(permissions.can?(:update, :anything)).to be true
      expect(permissions.can?(:delete, :anything)).to be true
    end

    it "is equivalent to wildcards for any subject" do
      expect(permissions.can?(:action, :posts)).to be true
      expect(permissions.can?(:action, :comments)).to be true
      expect(permissions.can?(:action, TestObject)).to be true
      expect(permissions.can?(:action, TestObject.new)).to be true
    end
  end

  describe "default user_role_identifiers behavior" do
    let(:base_permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions do
          can :action, :subject
        end
        # Intentionally not overriding user_role_identifiers
      end
    end
    let(:user) { TestUser.new(id: 1) }
    let(:permissions) { base_permissions_class.new(user) }

    it "returns empty array by default" do
      expect(permissions.user_role_identifiers).to eq([])
    end

    it "results in no permissions when not overridden" do
      expect(permissions.can?(:action, :subject)).to be false
    end
  end

  describe "when user has nil role identifier" do
    let(:permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions(:member) do
          can :action, :subject
        end

        def user_role_identifiers
          [nil]
        end
      end
    end
    let(:user) { TestUser.new(id: 1) }
    let(:permissions) { permissions_class.new(user) }

    it "denies access for nil role" do
      expect(permissions.can?(:action, :subject)).to be false
    end
  end

  describe "when user has mix of valid and nil role identifiers" do
    let(:permissions_class) do
      Class.new(Ingress::Permissions) do
        define_role_permissions(:member) do
          can :action, :subject
        end

        def user_role_identifiers
          [:member, nil]
        end
      end
    end
    let(:user) { TestUser.new(id: 1) }
    let(:permissions) { permissions_class.new(user) }

    it "grants access based on valid role, ignores nil" do
      expect(permissions.can?(:action, :subject)).to be true
    end
  end
end

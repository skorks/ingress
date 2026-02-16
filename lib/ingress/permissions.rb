# frozen_string_literal: true

require "ingress/permissions_repository"
require "ingress/copy_permissions_repository_into_role"
require "ingress/build_permissions_repository_for_role"

module Ingress
  class Permissions
    # Internal sentinel role used when permissions are defined without an explicit role.
    # Uses a distinct name to avoid collision with user-defined roles.
    ANONYMOUS_ROLE = :"__ingress_anonymous__"
    private_constant :ANONYMOUS_ROLE

    class << self
      def permissions_repository
        @permissions_repository ||= PermissionsRepository.new
      end

      def inherits(permissions_class)
        role_identifier = ANONYMOUS_ROLE

        return unless permissions_class

        @permissions_repository = permissions_repository.merge(
          Services::CopyPermissionsRepositoryIntoRole.perform(role_identifier,
                                                              permissions_class.permissions_repository)
        )
      end

      def define_role_permissions(role_identifier = nil, permissions_class = nil, &)
        role_identifier = ANONYMOUS_ROLE if role_identifier.nil?

        if permissions_class
          @permissions_repository = permissions_repository.merge(
            Services::CopyPermissionsRepositoryIntoRole.perform(role_identifier,
                                                                permissions_class.permissions_repository)
          )
        end

        return unless block_given?

        @permissions_repository = permissions_repository.merge(Services::BuildPermissionsRepositoryForRole.perform(
                                                                 role_identifier, &
                                                               ))
      end
    end

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def can?(action, subject, options = {})
      user_role_identifiers.any? do |role_identifier|
        rules = self.class.permissions_repository.rules_for(role_identifier, action, subject)

        cannot_match = rules.reject(&:allows?).any? do |rule|
          rule.match?(action, subject, user, options)
        end
        break false if cannot_match

        rules.select(&:allows?).any? do |rule|
          rule.match?(action, subject, user, options)
        end
      end
    end

    def user_role_identifiers
      []
    end
  end
end

require "ingress/permissions_dsl"

module Ingress
  module Services
    class BuildPermissionsRepositoryForRole
      class << self
        def perform(role_identifier, &block)
          permissions_dsl = PermissionsDsl.new(role_identifier)
          permissions_dsl.instance_eval(&block)
          permissions_dsl.permission_repository
        end
      end
    end
  end
end

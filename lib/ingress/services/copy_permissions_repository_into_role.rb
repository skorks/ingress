# take an existing permissions repository and copy all rules from there into
# another repository under a particular role
module Ingress
  module Services
    class CopyPermissionsRepositoryIntoRole
      class << self
        def perform(role_identifier, template_permission_repository)
          permission_repository = PermissionsRepository.new
          permission_repository.copy_to_role(role_identifier, template_permission_repository)
          permission_repository
        end
      end
    end
  end
end

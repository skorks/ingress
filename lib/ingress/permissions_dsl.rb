# the public interface of this class defines the dsl you can use to define
# permissions
module Ingress
  class PermissionsDsl
    attr_reader :role_identifier, :permission_repository

    def initialize(role_identifier)
      @role_identifier = role_identifier
      @permission_repository = PermissionsRepository.new
    end

    def can_do_anything
      permission_repository.add_permission(role_identifier, true, "*", "*")
    end

    def can(actions, subjects, options = {}, &block)
      for_each_action_and_subject(actions, subjects) do |action, subject|
        condition = condition_from_options(options, block)
        permission_repository.add_permission(role_identifier, true, action, subject, condition)
      end
    end

    def cannot(actions, subjects, options = {}, &block)
      for_each_action_and_subject(actions, subjects) do |action, subject|
        condition = condition_from_options(options, block)
        permission_repository.add_permission(role_identifier, false, action, subject, condition)
      end
    end

    private

    def for_each_action_and_subject(actions, subjects)
      return unless block_given?
      actions = [actions].flatten
      subjects = [subjects].flatten

      actions.each do |action|
        subjects.each do |subject|
          yield(action, subject)
        end
      end
    end

    def condition_from_options(options, block)
      if_condition = options[:if] || block
      if_condition.respond_to?(:call) ? if_condition : nil
    end
  end
end

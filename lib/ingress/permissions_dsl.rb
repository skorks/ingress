require "ingress/permissions_repository"

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
        conditions = conditions_from(options, block)

        permission_repository.add_permission(role_identifier, true, action, subject, conditions)
      end
    end

    def cannot(actions, subjects, options = {}, &block)
      for_each_action_and_subject(actions, subjects) do |action, subject|
        conditions = conditions_from(options, block)

        permission_repository.add_permission(role_identifier, false, action, subject, conditions)
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

    def conditions_from(options, block)
      generic_condition = generic_condition_from(options[:if] || block)
      instance_condition = if_subject_is_an_instance_condition_from(options[:if_subject_is_an_instance])
      class_condition = if_subject_is_a_class_condition_from(options[:if_subject_is_a_class])

      [generic_condition, instance_condition, class_condition].compact
    end

    def generic_condition_from(callback)
      callback if callback&.respond_to?(:call)
    end

    def if_subject_is_an_instance_condition_from(callback)
      if callback&.respond_to?(:call)
        lambda do |user, given_subject, option|
          if [Class, Module].include?(given_subject.class)
            true
          else
            callback.call(user, given_subject, option)
          end
        end
      end
    end

    def if_subject_is_a_class_condition_from(callback)
      if callback&.respond_to?(:call)
        lambda do |user, given_subject, option|
          if [Class, Module].include?(given_subject.class)
            callback.call(user, given_subject, option)
          else
            true
          end
        end
      end
    end
  end
end

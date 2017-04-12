require "ingress/permission_rule"

module Ingress
  class PermissionsRepository
    attr_reader :role_rules

    def initialize
      @role_rules = Hashes.role_rules
      @role_subject_action_rule = Hashes.role_subject_action_rule
    end

    def add_permission(role_identifier, allow, action, subject, conditions = nil)
      rule = PermissionRule.new(allows: allow, action: action, subject: subject, conditions: conditions)
      add_rule(role_identifier, rule)
    end

    def rules_for(role_identifier, action, subject)
      rules = []

      rules += find_rules(role_identifier, action, subject)
      rules += find_rules(role_identifier, "*", "*")
      rules += find_rules(role_identifier, action, "*")
      rules += find_rules(role_identifier, "*", subject)
      rules = apply_negative_rules(rules)

      rules
    end

    def merge(permission_repository)
      permission_repository.role_rules.each_pair do |role_identifier, rules|
        rules.each do |rule|
          add_rule(role_identifier, rule)
        end
      end
      self
    end

    def copy_to_role(role_identifier, permission_repository)
      permission_repository.role_rules.each_pair do |_, rules|
        rules.each do |rule|
          add_rule(role_identifier, rule)
        end
      end
      self
    end

    private

    def apply_negative_rules(rules)
      # remove rules that cancel each other out since we're within the
      # context of 1 role, i.e. if any rule is a negation it will
      # cancel all other ones
      if rules.any? { |rule| !rule.allows? }
        []
      else
        rules
      end
    end

    def find_rules(role_identifier, action, subject)
      rules = []
      rules += @role_subject_action_rule[role_identifier][subject][action]
      unless subject == "*"
        rules += @role_subject_action_rule[role_identifier][subject.class][action]
      end

      rules
    end

    def add_rule(role_identifier, rule)
      @role_rules[role_identifier] << rule
      @role_subject_action_rule[role_identifier][rule.subject][rule.action] << rule
    end

    # creates hashes with the default values required in
    # PermissionsRepository's constructor
    module Hashes
      module_function

      # Three level deep hash returning an array
      def role_subject_action_rule
        Hash.new do |hash1, key1|
          hash1[key1] = Hash.new do |hash2, key2|
            hash2[key2] = Hash.new do |hash3, key3|
              hash3[key3] = []
            end
          end
        end
      end

      # One level deep hash returning an array
      def role_rules
        Hash.new { |hash, key| hash[key] = [] }
      end
    end
  end
end

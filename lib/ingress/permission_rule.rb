# a rule that defines one permission, it's agnostic of role
module Ingress
  class PermissionRule
    attr_reader :action, :subject, :conditions

    def initialize(allows:, action:, subject:, conditions: nil)
      @allows = allows
      @action = action
      @subject = subject
      @conditions = [conditions].compact.flatten
    end

    def allows?
      @allows
    end

    def match?(given_action, given_subject, user)
      return false unless action_matches?(given_action)
      return false unless subject_matches?(given_subject)

      conditions_match?(user, given_subject)
    end

    private

    def action_matches?(given_action)
      given_action == action ||
        given_action == "*" ||
        "*" == action
    end

    def subject_matches?(given_subject)
      given_subject == subject ||
        given_subject.class == subject ||
        given_subject == "*" ||
        "*" == subject
    end

    def conditions_match?(user, given_subject)
      conditions.all? do |condition|
        condition.call(user, given_subject)
      end
    rescue => e
      log_error(e)
      false
    end

    def log_error(error)
      if defined?(Rails)
        Rails.logger.error error.message
        Rails.logger.error error.backtrace.join("\n")
      else
        $stderr.puts error.message
        $stderr.puts error.backtrace.join("\n")
      end
    end
  end
end

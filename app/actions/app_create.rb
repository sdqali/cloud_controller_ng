module VCAP::CloudController
  class AppCreate
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
      @logger     = Steno.logger('cc.action.app_create')
    end

    def create(message)
      raise 'buildpack not found' if !message.buildpack.nil? && !validate_buildpack(message)

      app = AppModel.create(
        name:                  message.name,
        space_guid:            message.space_guid,
        environment_variables: message.environment_variables,
        buildpack:             message.buildpack)

      @logger.info("Created app #{app.name} #{app.guid}")
      Event.create({
        type:              'audit.app.create',
        actee:             app.guid,
        actee_type:        'v3-app',
        actee_name:        message.name,
        actor:             @user.guid,
        actor_type:        'user',
        actor_name:        @user_email,
        space_guid:        message.space_guid,
        organization_guid: app.space.organization.guid,
        timestamp:         Sequel::CURRENT_TIMESTAMP,
      })

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def validate_buildpack(message)
      if !valid_url?(message.buildpack)
        buildpack = Buildpack.find(name: message.buildpack)
        return false if buildpack.nil?
      end

      true
    end

    def valid_url?(url)
      begin
        uri = URI.parse(url)
        return false if !(uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS))
      rescue URI::InvalidURIError
        return false
      end

      true
    end
  end
end

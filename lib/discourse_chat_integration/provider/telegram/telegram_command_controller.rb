# frozen_string_literal: true

module DiscourseChatIntegration::Provider::TelegramProvider
  class TelegramCommandController < DiscourseChatIntegration::Provider::HookController
    requires_provider ::DiscourseChatIntegration::Provider::TelegramProvider::PROVIDER_NAME

    before_action :telegram_token_valid?, only: :command

    skip_before_action :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       only: :command

    def command

      # Always give telegram a success message, otherwise we'll stop receiving webhooks
      data = {
        success: true
      }
      render json: data
    end

    def process_command(message)
      chat_id = params['message']['chat']['id']

      provider = DiscourseChatIntegration::Provider::TelegramProvider::PROVIDER_NAME

      channel = DiscourseChatIntegration::Channel.with_provider(provider).with_data_value('chat_id', chat_id).first

      text_key = "unknown_chat" if channel.nil?
      # If slash commands disabled, send a generic message
      text_key = "known_chat" if !SiteSetting.chat_integration_telegram_enable_slash_commands
      text_key = "help" if message['text'].blank?

      if text_key.present?
        return  I18n.t(
          "chat_integration.provider.telegram.#{text_key}",
          site_title: CGI::escapeHTML(SiteSetting.title),
          chat_id: chat_id,
        )
      end

      tokens = message['text'].split(" ")

      tokens[0][0] = '' # Remove the slash from the first token
      tokens[0] = tokens[0].split('@')[0] # Remove the bot name from the command (necessary for group chats)

      ::DiscourseChatIntegration::Helper.process_command(channel, tokens)
    end

    def telegram_token_valid?
      params.require(:token)

      if SiteSetting.chat_integration_telegram_secret.blank? ||
         SiteSetting.chat_integration_telegram_secret != params[:token]

        raise Discourse::InvalidAccess.new
      end
    end
  end

  class TelegramEngine < ::Rails::Engine
    engine_name DiscourseChatIntegration::PLUGIN_NAME + "-telegram"
    isolate_namespace DiscourseChatIntegration::Provider::TelegramProvider
  end

  TelegramEngine.routes.draw do
    post "command/:token" => "telegram_command#command"
  end
end

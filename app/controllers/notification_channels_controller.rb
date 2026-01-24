# frozen_string_literal: true

class NotificationChannelsController < ApplicationController
  before_action :set_notification_channel, only: [ :show, :edit, :update, :destroy, :test ]

  def index
    @notification_channels = current_user.notification_channels.order(created_at: :desc)
  end

  def show
    @backup_jobs = @notification_channel.backup_jobs.includes(:database_config)
  end

  def new
    @notification_channel = current_user.notification_channels.build
    @channel_type = params[:type] || "email"
  end

  def create
    channel_class = channel_class_for(params[:notification_channel][:channel_type])
    @notification_channel = channel_class.new(notification_channel_params)
    @notification_channel.user = current_user

    if @notification_channel.save
      AuditLog.log(
        action: "create_notification_channel",
        user: current_user,
        resource: @notification_channel,
        ip_address: request.remote_ip
      )
      redirect_to notification_channel_path(@notification_channel), notice: "Notification channel created successfully."
    else
      @channel_type = params[:notification_channel][:channel_type]
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @channel_type = @notification_channel.channel_type
  end

  def update
    if @notification_channel.update(notification_channel_params)
      AuditLog.log(
        action: "update_notification_channel",
        user: current_user,
        resource: @notification_channel,
        ip_address: request.remote_ip
      )
      redirect_to notification_channel_path(@notification_channel), notice: "Notification channel updated successfully."
    else
      @channel_type = @notification_channel.channel_type
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @notification_channel.destroy
    AuditLog.log(
      action: "delete_notification_channel",
      user: current_user,
      resource: @notification_channel,
      ip_address: request.remote_ip
    )
    redirect_to notification_channels_path, notice: "Notification channel deleted successfully."
  end

  def test
    result = NotificationService.test_channel(@notification_channel)

    AuditLog.log(
      action: "test_notification_channel",
      user: current_user,
      resource: @notification_channel,
      details: result,
      ip_address: request.remote_ip
    )

    if result[:success]
      redirect_to notification_channel_path(@notification_channel), notice: "Test notification sent successfully!"
    else
      redirect_to notification_channel_path(@notification_channel), alert: "Test notification failed: #{result[:error]}"
    end
  end

  private

  def set_notification_channel
    @notification_channel = current_user.notification_channels.find(params[:id])
  end

  def notification_channel_params
    permitted = [ :name, :enabled, :notify_on_success, :notify_on_failure ]

    # Use existing channel type for updates, form param for creates
    channel_type = params.dig(:notification_channel, :channel_type) || @notification_channel&.channel_type

    config_params = case channel_type
    when "email"
      {
        to_address: params.dig(:notification_channel, :config, :to_address),
        from_address: params.dig(:notification_channel, :config, :from_address)
      }.compact
    when "slack"
      {
        webhook_url: params.dig(:notification_channel, :config, :slack_webhook_url),
        channel: params.dig(:notification_channel, :config, :channel)
      }.compact
    when "discord"
      {
        webhook_url: params.dig(:notification_channel, :config, :discord_webhook_url)
      }.compact
    when "telegram"
      {
        bot_token: params.dig(:notification_channel, :config, :bot_token),
        chat_id: params.dig(:notification_channel, :config, :chat_id)
      }.compact
    when "webhook"
      {
        url: params.dig(:notification_channel, :config, :url),
        method: params.dig(:notification_channel, :config, :method),
        headers: parse_headers(params.dig(:notification_channel, :config, :headers))
      }.compact
    else
      {}
    end

    result = params.require(:notification_channel).permit(*permitted)
    result[:config] = config_params
    result
  end

  def channel_class_for(type)
    case type
    when "email"
      NotificationChannels::EmailChannel
    when "slack"
      NotificationChannels::SlackChannel
    when "discord"
      NotificationChannels::DiscordChannel
    when "telegram"
      NotificationChannels::TelegramChannel
    when "webhook"
      NotificationChannels::WebhookChannel
    else
      NotificationChannel
    end
  end

  def parse_headers(headers_string)
    return {} if headers_string.blank?

    headers_string.split("\n").each_with_object({}) do |line, hash|
      key, value = line.split(":", 2)
      hash[key.strip] = value&.strip if key.present?
    end
  end
end

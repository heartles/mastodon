# frozen_string_literal: true

module TwoFactorAuthenticationConcern
  extend ActiveSupport::Concern

  included do
    prepend_before_action :authenticate_with_two_factor, if: :two_factor_enabled?, only: [:create]
  end

  def two_factor_enabled?
    find_user&.otp_required_for_login?
  end

  def valid_otp_attempt?(user)
    user.validate_and_consume_otp!(user_params[:otp_attempt]) ||
      user.invalidate_otp_backup_code!(user_params[:otp_attempt])
  rescue OpenSSL::Cipher::CipherError
    false
  end

  def authenticate_with_two_factor
    user = self.resource = find_user

    if user_params[:otp_attempt].present? && session[:attempt_user_id]
      authenticate_with_two_factor_attempt(user)
    elsif user.present? && user.external_or_valid_password?(user_params[:password])
      prompt_for_two_factor(user)
    end
  end

  def authenticate_with_two_factor_attempt(user)
    if valid_otp_attempt?(user)
      session.delete(:attempt_user_id)
      remember_me(user)
      sign_in(user)
    else
      flash.now[:alert] = I18n.t('users.invalid_otp_token')
      prompt_for_two_factor(user)
    end
  end

  def prompt_for_two_factor(user)
    set_locale do
      session[:attempt_user_id] = user.id
      use_pack 'auth'
      @body_classes = 'lighter'
      render :two_factor
    end
  end
end

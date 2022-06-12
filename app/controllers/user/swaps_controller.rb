class User::SwapsController < ApplicationController
  before_action :require_swapping_open, only: [:show, :new, :create]
  before_action :require_login
  before_action :assert_incoming_swap_exists, only: [:destroy]
  before_action :assert_swap_exists, only: [:update]
  before_action :assert_parties_exist, only: [:show]
  before_action :assert_has_email, only: [:new, :create, :update]
  before_action :assert_has_constituency, only: [:new, :create, :update]
  before_action :assert_mobile_phone_verified, only: [:new, :create, :update]
  before_action :two_party_by_election, only: [:show, :new]

  include UsersHelper

  def show
    @mobile_number = @user.mobile_number
    if @user.swapped?
      redirect_to user_path
      return
    end
    @potential_swaps = @user.potential_swap_users(5)
  end

  def new
    @swap_with = User.find(params[:user_id])
  end

  def create
    @user.swap_with_user_id(params[:user_id], params[:consent_share_email_chooser])
    unless @user.errors.empty?
      flash[:errors] = @user.errors.full_messages
    end
    redirect_to user_path
  end

  def update
    if swap_params[:confirmed] == "true" && @user.swap_consent_given?(swap_params[:consent_share_email_chosen] == "on")
      @user.confirm_swap(swap_params)
    else
      swap_params.delete(:confirmed)
      @user.update_swap(swap_params)
    end

    unless @user.errors.empty?
      flash[:errors] = @user.errors.full_messages
    end

    redirect_to user_path
  end

  def destroy
    @user.clear_swap
    redirect_to user_path
  end

  private

  def two_party_by_election
    return @two_party_by_election if defined?(@two_party_by_election)
    @two_party_by_election = OnsConstituency.count == 2
  end

  def assert_mobile_phone_verified
    return unless @user.mobile_verification_missing?

    flash[:errors] = ["Please verify your mobile phone number before you swap!"]
    redirect_to edit_user_path
  end

  def assert_has_email
    return unless @user.email.blank?

    flash[:errors] = ["Please enter your email address before you swap!"]
    redirect_to edit_user_path
  end

  def assert_has_constituency
    return unless @user.constituency_ons_id.blank?

    flash[:errors] = ["Please enter your postcode or constituency before you swap!"]
    redirect_to edit_user_path
  end

  def assert_incoming_swap_exists
    return if @user.incoming_swap
    flash[:errors] = ["You don't have a swap!"]
    redirect_to user_path
  end

  def assert_swap_exists
    return if @user.incoming_swap || @user.outgoing_swap
    flash[:errors] = ["You don't have a swap!"]
    redirect_to user_path
  end

  def assert_parties_exist
    return if @user.willing_party && @user.preferred_party
    redirect_to edit_user_path
  end

  def swap_params
    params.require(:swap).permit(
      :confirmed,
      :consent_share_email_chooser,
      :consent_share_email_chosen,
      :consent_share_email
    )
  end
end

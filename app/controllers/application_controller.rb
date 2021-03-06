class ApplicationController < ActionController::Base

  protect_from_forgery with: :exception
  include SessionsManagement
  before_action :set_locale
  before_action :set_new_donation
  helper_method :current_user, :logged_in?, :current_user?, :login_path

  rescue_from OAuth::Unauthorized, with: :external_service_unauthorized

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def default_url_options(options={})
    { locale: I18n.locale }
  end

  def login_path
    root_path(anchor: 'login')
  end

  def signup_path(params)
    root_path(params.merge(anchor: 'signup'))
  end

  protected

    def set_new_donation
      new_donation_currency = logged_in? ? current_user.currency : 'EUR'
      @donation = Donation.new currency: new_donation_currency,
                               project: (@project.nil? ? Project.new : @project)
    end

    def save_donation(donation_params)
      if donation_params[:project_attributes] && donation_params[:project_attributes][:id]
        project = Project.find_by(id: donation_params[:project_attributes][:id])
      end

      if donation_params[:recurring] == 'no'
        @donation = current_user.donations.build(donation_params.merge(project: project))
        if @donation.save
          cookies.delete(:donation) if cookies[:donation]
          redirect_to donation_complete_path(@donation, share_links: true)
        else
          # flash[:error] = t('.error_creating_donation', errors: @donation.errors.full_messages.to_sentence)
          modal_error('donation', t('.error_creating_donation', errors: @donation.errors.full_messages.to_sentence))
          redirect_to(:back)
        end
      else
        recurring_donation = current_user.recurring_donations.build(donation_params.merge(project: project))
        if recurring_donation.save
          # TODO: we redirect to the last donation created in the recurring donation
          #       We could probably show information about the recurring donation
          donation = recurring_donation.donations.sorted.last
          redirect_to donation_complete_path(donation, share_links: true)
        else
          @donation = Donation.new(attributes: recurring_donation.attributes.except('frequency_period', 'frequency_units', 'finished_at'))
          flash[:error] = t('.error_creating_donation', errors: recurring_donation.errors.full_messages.to_sentence)
          redirect_to(:back)
        end
      end
    end

    def cookie_donation
      JSON.parse(cookies[:donation]).with_indifferent_access
    end
    helper_method :cookie_donation

    def save_pending_donations
      if cookies[:donation]
        save_donation(cookie_donation)
        flash[:success] = "Hey, donation tracked, and you have your profile ready to keep tracking donations! Now this is a great day."
      end
    end

    def profile_owner
      @user = params[:id] ? User.find(params[:id]) : current_user

      redirect_to(root_path) unless @user == current_user
    end

    def external_service_unauthorized
      flash[:error] = t('.unauthorized')
      redirect_to root_path
    end

    def modal_error(flash_type, message)
      flash[:modal_error] = flash_type
      flash["modal_#{flash_type}_error".to_sym] = message
    end

end

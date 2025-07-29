class HealthController < ApplicationController
  skip_before_action :authenticate_admin!
  
  def check
    render json: {
      status: 'OK',
      timestamp: Time.current,
      version: '1.0.0',
      environment: Rails.env
    }
  end
end 
class ApplicationController < ActionController::API
  include JsonWebToken
  include Cacheable

  before_action :authenticate_admin!

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from JWT::DecodeError, with: :invalid_token
  rescue_from JWT::ExpiredSignature, with: :token_expired
  rescue_from StandardError, with: :internal_server_error
  
  protected
  
    def authenticate_admin!
    header = request.headers['Authorization']
    token = header.split(' ').last if header
    
    if token.present?
      begin
        decoded = jwt_decode(token)
        admin_id = decoded['admin_id']
        @current_admin = Admin.find(admin_id)
        
        # Set current admin for audit trail
        Current.admin = @current_admin
      rescue ActiveRecord::RecordNotFound
        render json: {
          status: 'error',
          message: 'Administrador no encontrado'
        }, status: :unauthorized
      rescue JWT::DecodeError => e
        render json: {
            status: 'error',
            message: 'Invalid token',
            details: e.message
        }, status: :unauthorized
      rescue JWT::ExpiredSignature => e
        render json: {
            status: 'error',
            message: 'Token expired',
            details: e.message
        }, status: :unauthorized
      end
    else
      render json: {
        status: 'error',
        message: 'Token is required'
      }, status: :unauthorized
    end
  end
  
  def current_admin
    @current_admin
  end

  private

  def record_not_found(exception)
    render_error(exception.message, nil, :not_found)
  end

  def record_invalid(exception)
    render_error('Error de validación', exception.record.errors.full_messages.join(', '), :unprocessable_entity)
  end

  def parameter_missing(exception)
    render_error('Parámetros faltantes', exception.message, :bad_request)
  end

  def invalid_token
    render_error('Token inválido', nil, :unauthorized)
  end

  def token_expired
    render_error('Token expirado', nil, :unauthorized)
  end

  def internal_server_error(exception)
    Rails.logger.error "Error interno: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    render_error('Error interno del servidor', nil, :internal_server_error)
  end
  
  def render_success(data = nil, message = 'Success')
    render json: {
      status: 'success',
      message: message,
      data: data
    }, status: :ok
  end
  
  def render_error(message = 'Error', details = nil, status = :unprocessable_entity)
    render json: {
      status: 'error',
      message: message,
      details: details
    }, status: status
  end
end

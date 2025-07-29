class Api::V1::AuthenticationController < ApplicationController
  skip_before_action :authenticate_admin!, only: [:login]
  
  # POST /api/v1/login
  def login
    admin = Admin.find_by(email: params[:email])
    
    if admin&.authenticate(params[:password])
      token = admin.generate_jwt_token
      
      render json: {
        status: 'success',
        message: 'Login successful',
        data: {
          token: token,
          admin: {
            id: admin.id,
            email: admin.email,
            name: admin.name
          }
        }
      }, status: :ok
    else
      render json: {
        status: 'error',
        message: 'Invalid email or password'
      }, status: :unauthorized
    end
  end
  
  # POST /api/v1/logout
  def logout
    # En JWT stateless no necesitamos hacer nada especial
    render json: {
      status: 'success',
      message: 'Logout successful'
    }, status: :ok
  end
  
  # GET /api/v1/me
  def me
    render json: {
      status: 'success',
      data: {
        admin: {
          id: current_admin.id,
          email: current_admin.email,
          name: current_admin.name,
          products_count: current_admin.products.count,
          categories_count: current_admin.categories.count
        }
      }
    }, status: :ok
  end
end

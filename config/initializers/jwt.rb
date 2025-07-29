# JWT Configuration
JWT_SECRET = Rails.application.credentials.secret_key_base

# JWT Algorithm
JWT_ALGORITHM = 'HS256'

# JWT Expiration time (24 hours)
JWT_EXPIRATION = 24.hours 
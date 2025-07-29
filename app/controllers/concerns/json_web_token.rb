module JsonWebToken
  extend ActiveSupport::Concern

  private

  def jwt_encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, JWT_SECRET, JWT_ALGORITHM)
  end

  def jwt_decode(token)
    decoded = JWT.decode(token, JWT_SECRET, true, { algorithm: JWT_ALGORITHM })
    decoded[0]
  rescue JWT::ExpiredSignature => e
    raise JWT::ExpiredSignature, e.message
  rescue JWT::DecodeError => e
    raise JWT::DecodeError, e.message
  end
end
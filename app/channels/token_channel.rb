class TokenChannel < ApplicationCable::Channel
  def subscribed
    token = Token.find_by(uuid: params[:token_uuid])

    if token
      stream_from "token_#{token.uuid}"
    else
      reject
    end
  end
end

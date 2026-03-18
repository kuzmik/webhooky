class TokensController < ApplicationController
  def create
    token = Token.create!
    redirect_to token_path(uuid: token.uuid)
  end

  def show
    @token = Token.find_by!(uuid: params[:uuid])
  end

  def update
    @token = Token.find_by!(uuid: params[:uuid])
    if @token.update(token_params)
      head :ok
    else
      render json: { errors: @token.errors }, status: :unprocessable_entity
    end
  end

  private

  def token_params
    params.permit(:default_status, :default_content_type, :default_content, :timeout, :cors)
  end
end

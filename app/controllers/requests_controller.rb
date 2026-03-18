class RequestsController < ApplicationController
  before_action :set_token

  def index
    page = (params[:page] || 1).to_i
    per_page = 50
    offset = (page - 1) * per_page

    requests = @token.webhook_requests.order(created_at: :desc).offset(offset).limit(per_page)
    total = @token.webhook_requests.count

    render json: {
      data: requests.as_json(except: :token_id),
      total: total,
      page: page,
      per_page: per_page
    }
  end

  def show
    request_record = @token.webhook_requests.find_by!(uuid: params[:uuid])
    render json: request_record.as_json(except: :token_id)
  end

  def destroy
    request_record = @token.webhook_requests.find_by!(uuid: params[:uuid])
    request_record.destroy!
    head :no_content
  end

  def destroy_all
    @token.webhook_requests.delete_all
    head :no_content
  end

  private

  def set_token
    @token = Token.find_by!(uuid: params[:token_uuid] || params[:uuid])
  end
end

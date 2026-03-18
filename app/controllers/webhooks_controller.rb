class WebhooksController < ApplicationController
  skip_forgery_protection

  MAX_BODY_SIZE = 1.megabyte
  MAX_REQUESTS_PER_TOKEN = 500

  def capture
    @token = Token.find_by(uuid: params[:uuid])
    return head(:not_found) unless @token

    body = request.raw_post || ""
    if body.bytesize > MAX_BODY_SIZE
      return head(:content_too_large)
    end

    headers_hash = extract_headers(request)
    query_hash = request.query_parameters

    form_data = if request.content_type&.match?(/form-urlencoded|multipart\/form-data/)
      request.request_parameters
    end

    webhook_request = @token.webhook_requests.create!(
      method_name: request.method,
      url: request.original_url,
      ip: request.remote_ip,
      hostname: request.host,
      content: body,
      headers: headers_hash.to_json,
      query: query_hash.to_json,
      form_data: form_data&.to_json,
      content_size: body.bytesize
    )

    cleanup_old_requests(@token)
    broadcast_request(webhook_request)

    status = (params[:status] || @token.default_status).to_i

    if @token.timeout.present? && @token.timeout > 0
      sleep([[@token.timeout, 10].min, 0].max)
    end

    response.headers["Access-Control-Allow-Origin"] = "*" if @token.cors
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD" if @token.cors
    response.headers["Access-Control-Allow-Headers"] = "*" if @token.cors

    render plain: @token.default_content,
           content_type: @token.default_content_type,
           status: status
  end

  private

  def extract_headers(request)
    headers = {}
    request.headers.each do |key, value|
      next unless key.start_with?("HTTP_") || %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)
      name = key.sub(/^HTTP_/, "").downcase.tr("_", "-")
      headers[name] = value
    end
    headers
  end

  def cleanup_old_requests(token)
    count = token.webhook_requests.count
    if count > MAX_REQUESTS_PER_TOKEN
      excess = count - MAX_REQUESTS_PER_TOKEN
      oldest_ids = token.webhook_requests.order(created_at: :asc).limit(excess).pluck(:uuid)
      WebhookRequest.where(uuid: oldest_ids).delete_all
    end
  end

  def broadcast_request(webhook_request)
    payload = {
      request: webhook_request.attributes.except("token_id"),
      total: webhook_request.token.webhook_requests.count
    }

    if payload.to_json.bytesize > 100_000
      payload[:request] = payload[:request].except("content", "headers")
      payload[:truncated] = true
    end

    ActionCable.server.broadcast("token_#{webhook_request.token_id}", payload)
  end
end

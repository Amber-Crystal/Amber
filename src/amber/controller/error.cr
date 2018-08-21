require "./base"
require "../exceptions/exception_page"

module Amber::Controller
  class Error < Base
    def initialize(@context : HTTP::Server::Context, @ex : Exception)
      super(@context)
      @context.response.content_type = content_type
    end

    def bad_request
      response_format
    end

    def forbidden
      response_format
    end

    def not_found
      response_format
    end

    def internal_server_error
      response_format
    end

    private def content_type
      if context.request.headers["Accept"]?
        request.headers["Accept"].split(",").first
      else
        "text/plain"
      end
    end

    private def response_format
      case content_type
      when "application/json"
        {"error": @ex.message}.to_json
      when "text/html"
        Amber::Exceptions::ExceptionPageClient.new(@context, @ex).to_s
      else
        @ex.message
      end
    end
  end
end

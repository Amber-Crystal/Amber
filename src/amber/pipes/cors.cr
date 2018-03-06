require "./base"

module Amber
  module Pipe
    module Headers
      VARY              = "Vary"
      ORIGIN            = "Origin"
      X_ORIGIN          = "X-Origin"
      REQUEST_METHOD    = "Access-Control-Request-Method"
      REQUEST_HEADERS   = "Access-Control-Request-Headers"
      ALLOW_EXPOSE      = "Access-Control-Expose-Headers"
      ALLOW_ORIGIN      = "Access-Control-Allow-Origin"
      ALLOW_METHOD      = "Access-Control-Allow-Method"
      ALLOW_HEADERS     = "Access-Control-Allow-Headers"
      ALLOW_CREDENTIALS = "Access-Control-Allow-Credentials"
      ALLOW_MAX_AGE     = "Access-Control-Max-Age"
    end

    class CORS < Base
      alias OriginType = Array(String | Regex)
      FORBIDDEN     = "Forbidden for invalid origins, methods or headers"
      ALLOW_METHODS = %w(PUT PATCH DELETE)
      ALLOW_HEADERS = %w(Accept Content-type)

      property origins, headers, methods, credentials, max_age
      @origin : Origin

      def initialize(
        @origins : OriginType = ["*", %r()],
        @methods = ALLOW_METHODS,
        @headers = ALLOW_HEADERS,
        @credentials = false,
        @max_age : Int32? = 0,
        @expose_headers : Array(String)? = nil,
        @vary : String? = nil
      )
        @origin = Origin.new(origins)
      end

      def call(context : HTTP::Server::Context)
        if @origin.match?(context.request)
          put_expose_header(context.response)
          Preflight.request?(context, self)
          put_response_headers(context.response)
          call_next(context)
        else
          return forbidden(context)
        end
      end

      def forbidden(context)
        context.response.headers["Content-Type"] = "text/plain"
        context.response.respond_with_error FORBIDDEN, 403
      end

      private def put_expose_header(response)
        response.headers[Headers::ALLOW_EXPOSE] = @expose_headers.as(Array).join(",") if @expose_headers
      end

      private def put_response_headers(response)
        response.headers[Headers::ALLOW_CREDENTIALS] = @credentials.to_s if @credentials
        response.headers[Headers::ALLOW_ORIGIN] = @origin.request_origin.not_nil!
        response.headers[Headers::VARY] = vary unless @origin.any?
      end

      private def vary
        String.build do |str|
          str << Headers::ORIGIN
          str << "," << @vary if @vary
        end
      end
    end

    module Preflight
      extend self

      def request?(context, cors)
        if context.request.method == "OPTIONS"
          if valid_method?(context.request, cors.methods) &&
             valid_headers?(context.request, cors.headers)
            put_preflight_headers(context.request, context.response, cors.max_age)
          else
            cors.forbidden(context)
          end
        end
      end

      def put_preflight_headers(request, response, max_age)
        response.headers[Headers::ALLOW_METHOD] = request.headers[Headers::REQUEST_METHOD]
        response.headers[Headers::ALLOW_HEADERS] = request.headers[Headers::REQUEST_HEADERS]
        response.headers[Headers::ALLOW_MAX_AGE] = max_age.to_s if max_age
        response.content_length = 0
        response.flush
      end

      def valid_method?(request, methods)
        methods.includes? request.headers[Headers::REQUEST_METHOD]?
      end

      def valid_headers?(request, headers)
        !(headers & request.headers[Headers::REQUEST_HEADERS].split(',')).empty?
      end
    end

    struct Origin
      getter request_origin : String?

      def initialize(@origins : CORS::OriginType)
      end

      def match?(request)
        return false if @origins.empty?
        return false unless origin_header?(request)
        return true if any?

        @origins.any? do |origin|
          case origin
          when String then origin == request_origin
          when Regex  then origin =~ request_origin
          end
        end
      end

      def any?
        @origins.includes? "*"
      end

      private def origin_header?(request)
        @request_origin ||= request.headers[Headers::ORIGIN]? || request.headers[Headers::X_ORIGIN]?
      end
    end
  end
end

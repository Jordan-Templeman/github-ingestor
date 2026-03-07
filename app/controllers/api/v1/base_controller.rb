module Api
  module V1
    class BaseController < ApplicationController
      MAX_PAGE_LIMIT = 100
      DEFAULT_PAGE_LIMIT = 25

      rescue_from StandardError, with: :render_internal_error

      private

      def page_limit
        requested = params.dig(:page, :limit).to_i
        return DEFAULT_PAGE_LIMIT if requested <= 0

        [requested, MAX_PAGE_LIMIT].min
      end

      def page_offset
        offset = params.dig(:page, :offset).to_i
        [offset, 0].max
      end

      def render_not_found(resource_name)
        render json: {
          errors: [
            { status: '404', title: 'Not Found', detail: "#{resource_name} not found" },
          ],
        }, status: :not_found
      end

      def render_internal_error(exception)
        Rails.logger.error("[API] #{exception.class}: #{exception.message}")
        render json: {
          errors: [
            { status: '500', title: 'Internal Server Error', detail: 'An unexpected error occurred' },
          ],
        }, status: :internal_server_error
      end
    end
  end
end

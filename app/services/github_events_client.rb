class GithubEventsClient
  EVENTS_PATH = '/events'.freeze

  class RateLimitedError < StandardError; end
  class ApiError < StandardError; end

  class << self
    def fetch
      url = "#{GithubApiConfig::BASE_URL}#{EVENTS_PATH}"
      response = HTTParty.get(url, headers: GithubApiConfig::HEADERS, timeout: GithubApiConfig::TIMEOUT)

      handle_rate_limit(response)
      handle_errors(response)

      Rails.logger.info(
        "[GithubEventsClient] GET #{url} status=#{response.code} " \
        "rate_limit_remaining=#{response.headers['X-RateLimit-Remaining']}"
      )

      response.parsed_response
    end

    private

    def handle_rate_limit(response)
      if response.code == 429
        retry_after = response.headers['Retry-After']
        Rails.logger.warn("[GithubEventsClient] 429 Too Many Requests — retry-after=#{retry_after}")
        raise RateLimitedError, "Rate limit exhausted — retry after #{retry_after}s"
      end

      remaining_header = response.headers['X-RateLimit-Remaining']
      return if remaining_header.nil?

      remaining = remaining_header.to_i
      return unless remaining.zero?

      reset_at = response.headers['X-RateLimit-Reset']
      reset_time = Time.at(reset_at.to_i).utc.iso8601
      Rails.logger.warn("[GithubEventsClient] Rate limit exhausted — resets at #{reset_time}")
      raise RateLimitedError, "Rate limit exhausted — resets at #{reset_time}"
    end

    def handle_errors(response)
      return if response.success?
      return if response.code == 429

      raise ApiError, "GitHub API error: #{response.code} #{response.message}"
    end
  end
end

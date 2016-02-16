class CachedResponse
  include CacheControlRestrictable

  DEFAULT_MAX_AGE = 3600

  attr_reader :body, :status

  def initialize(args={})
    @body = args["body"]
    @status = args["status"]
    @headers = args["headers"]
  end

  def fresh?(request)
    Time.now <= expiration_date(request)
  end

  def add_x_from_acorn_cache_header
    headers["X-From-Acorn-Cache"] = "true"
  end

  def to_a
    [status, headers, [body]]
  end

  private

  attr_reader :headers

  def expiration_date(request)
    if max_age_specified?
      header_value_to_time("Date") + more_restrictive_max_age(response)
    elsif headers["Expiration"]
      header_value_to_time("Expiration")
    else
      header_value_to_time("Date") + DEFAULT_MAX_AGE
    end
  end

  def more_restrictive_max_age(request)
    if request.max_age_specified? && (max_age > request.max_age)
      request.max_age
    else
      max_age
    end
  end

  def header_value_to_time(header)
    headers[header].to_time
  end
end
require 'minitest/autorun'
require 'acorn_cache/cached_response'
require 'mocha/mini_test'

class CachedResponseTest < Minitest::Test
  def test_new
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "private" },
             "body" => "test body" }

    Rack::AcornCache::CacheControlHeader.expects(:new).with("private")

    cached_response = Rack::AcornCache::CachedResponse.new(args)

    assert_equal 200, cached_response.status
    assert_equal({ "Cache-Control" => "private" },  cached_response.headers)
    assert_equal "test body", cached_response.body
  end

  def test_no_cache_delegation
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "no-cache" },
             "body" => "test body" }

    cache_control_header = mock("cache control header")
    cache_control_header.expects(:no_cache?).returns(true)
    Rack::AcornCache::CacheControlHeader.expects(:new).returns(cache_control_header)

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    assert cached_response.no_cache?
  end

  def test_must_revalidate_delegation
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "must-revalidate" },
             "body" => "test body" }

    cache_control_header = mock("cache control header")
    cache_control_header.expects(:must_revalidate?).returns(true)
    Rack::AcornCache::CacheControlHeader.expects(:new).returns(cache_control_header)

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    assert cached_response.must_revalidate?
  end

  def test_max_age_delegation
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "max-age=30" },
             "body" => "test body" }

    cache_control_header = mock("cache control header")
    cache_control_header.expects(:max_age).returns(30)
    Rack::AcornCache::CacheControlHeader.expects(:new).returns(cache_control_header)

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    assert_equal 30, cached_response.max_age
  end

  def test_s_max_age_delegation
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "s-maxage=30" },
             "body" => "test body" }

    cache_control_header = mock("cache control header")
    cache_control_header.expects(:s_maxage).returns(30)
    Rack::AcornCache::CacheControlHeader.expects(:new).returns(cache_control_header)

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    assert_equal 30, cached_response.s_maxage
  end

  def test_must_be_revalidated
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "no-cache" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    cached_response.expects(:no_cache?).returns(true)

    assert cached_response.must_be_revalidated?
  end

  def test_update_date!
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "no-cache" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    current_time = mock('current_time')
    current_time.expects(:httpdate).returns(Time.now.httpdate)

    cached_response.update_date!
    assert_equal current_time.httpdate, cached_response.headers["Date"]
  end

  def test_serialize
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "no-cache" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.serialize

    assert_equal "{\"headers\":{\"Cache-Control\":\"no-cache\"},\"status\":200,\"body\":\"test body\"}", result
  end

  def test_to_a
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "no-cache" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.to_a

    assert_equal [200, {"Cache-Control"=>"no-cache"}, ["test body"]], result
  end

  def test_etag_header
    args = { "status" => 200,
             "headers" =>  { "ETag" => "-1087556166" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.etag_header

    assert_equal "-1087556166", result
  end

  def test_last_modified_header
    args = { "status" => 200,
             "headers" =>  { "Last-Modified" => "Mon, 01 Jan 2000 00:00:01 GMT" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.last_modified_header

    assert_equal "Mon, 01 Jan 2000 00:00:01 GMT", result
  end

  def test_update_date_and_recache!
    args = { "status" => 200,
             "headers" =>  { "X-Acorn-Cache" => "already-exists" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)

    assert cached_response
  end

  def test_add_acorn_cache_header_when_already_present
    args = { "status" => 200,
             "headers" =>  { "X-Acorn-Cache" => "already-exists" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.add_acorn_cache_header!

    assert_equal "already-exists", result.headers["X-Acorn-Cache"]
    assert cached_response
  end

  def test_add_acorn_cache_header_when_not_already_present
    args = { "status" => 200,
             "headers" =>  { },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.add_acorn_cache_header!

    assert_equal "HIT", result.headers["X-Acorn-Cache"]
  end

  def test_matches_when_etag_header_present
    args = { "status" => 200,
             "headers" =>  { "ETag" => "-1087556166" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    server_response = mock("server response")
    server_response.expects(:etag_header).returns("-1087556166")

    assert cached_response.matches?(server_response)
  end

  def test_matches_when_last_modified_header_present
    args = { "status" => 200,
             "headers" =>  { "Last-Modified" => "Mon, 01 Jan 2000 00:00:01 GMT" },
             "body" => "test body" }

   cached_response = Rack::AcornCache::CachedResponse.new(args)
   server_response = mock("server response")
   server_response.expects(:last_modified_header).returns("Mon, 01 Jan 2000 00:00:01 GMT")

   assert cached_response.matches?(server_response)
  end

  def test_matches_when_neither_header_is_present
    args = { "status" => 200,
             "headers" =>  { },
             "body" => "test body" }

   cached_response = Rack::AcornCache::CachedResponse.new(args)
   server_response = mock("server response")

   refute cached_response.matches?(server_response)
  end

  def test_time_to_live_when_s_maxage
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "s-maxage=30" },
             "body" => "test body" }

   cached_response = Rack::AcornCache::CachedResponse.new(args)
   result = cached_response.time_to_live

   assert_equal 30, result
  end

  def test_time_to_live_when_maxage
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "max-age=30" },
             "body" => "test body" }

   cached_response = Rack::AcornCache::CachedResponse.new(args)
   result = cached_response.time_to_live

   assert_equal 30, result
  end

  def test_time_to_live_when_expiration_header
    args = { "status" => 200,
             "headers" =>  { "Expiration" => "Mon, 01 Jan 2000 00:00:21 GMT", "Date" => "Mon, 01 Jan 2000 00:00:01 GMT" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.time_to_live

    assert_equal 20, result
  end

  def test_fresh_returns_true_using_max_age
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "max-age=30", "Date" => "Mon, 01 Jan 2000 00:00:01 GMT" },
             "body" => "test body" }

    Time.stubs(:now).returns(Time.at(0))
    cached_response = Rack::AcornCache::CachedResponse.new(args)
    cached_response.expects(:date).returns(Time.httpdate("Mon, 01 Jan 2000 00:00:01 GMT"))

    assert cached_response.fresh?
  end

  def test_fresh_returns_false_using_max_age
    args = { "status" => 200,
             "headers" =>  { "Cache-Control" => "max-age=30", "Date" => "Mon, 01 Jan 2000 00:00:01 GMT" },
             "body" => "test body" }

    Time.stubs(:now).returns(Time.new(2016, "jan", 1, 1, 1, 1))
    cached_response = Rack::AcornCache::CachedResponse.new(args)
    cached_response.expects(:date).returns(Time.httpdate("Mon, 01 Jan 2000 00:00:01 GMT"))

    refute cached_response.fresh?
  end

  def test_date
    args = { "status" => 200,
             "headers" =>  { "Date" => "Mon, 01 Jan 2000 00:00:01 GMT" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.date

    assert_equal Time.httpdate("Mon, 01 Jan 2000 00:00:01 GMT"), result
  end

  def test_expiration_date_if_s_maxage
    args = { "status" => 200,
             "headers" =>  { "Date" => "Mon, 01 Jan 2000 00:00:01 GMT", "Cache-Control" => "s-maxage=30" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.expiration_date

    assert_equal Time.httpdate("Mon, 01 Jan 2000 00:00:31 GMT"), result
  end

  def test_expiration_date_if_maxage
    args = { "status" => 200,
             "headers" =>  { "Date" => "Mon, 01 Jan 2000 00:00:01 GMT", "Cache-Control" => "max-age=30" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.expiration_date

    assert_equal Time.httpdate("Mon, 01 Jan 2000 00:00:31 GMT"), result
  end

  def test_expiration_date_if_expiration_header
    args = { "status" => 200,
             "headers" =>  { "Expiration" => "Mon, 01 Jan 2000 00:00:01 GMT" },           "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.expiration_date

    assert_equal Time.httpdate("Mon, 01 Jan 2000 00:00:01 GMT"), result
  end

  def test_expiration_date_for_default_max_age
    args = { "status" => 200,
             "headers" =>  { "Date" => "Mon, 01 Jan 2000 00:00:01 GMT" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)
    result = cached_response.expiration_date

    assert_equal Time.httpdate("Mon, 01 Jan 2000 01:00:01 GMT"), result
  end

  def test_not_modified_for_request
    request = stub(if_modified_since: Time.new(2016).httpdate,
                   if_none_match: "12345")

    args = { "status" => 200,
             "headers" =>  { "Date" => "Mon, 01 Jan 2000 00:00:01 GMT",
                             "ETag" => "12345",
                             "Last-Modified" => Time.new(2015).httpdate },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)

    assert cached_response.not_modified_for?(request)
  end

  def test_not_modified_for_request_only_etag
    request = stub(if_modified_since: nil, if_none_match: "12345")

    args = { "status" => 200,
             "headers" =>  { "Date" => "Mon, 01 Jan 2000 00:00:01 GMT",
                             "ETag" => "12345" },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)

    assert cached_response.not_modified_for?(request)
  end

  def test_not_modified_for_request_only_if_modified_since
    request = stub(if_modified_since: Time.new(2016).httpdate,
                   if_none_match: nil)

    args = { "status" => 200,
             "headers" =>  { "Date" => "Mon, 01 Jan 2000 00:00:01 GMT",
                             "Last-Modified" => Time.new(2015).httpdate },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)

    assert cached_response.not_modified_for?(request)
  end

  def test_modified_for_request_only_etag_differs
    request = stub(if_modified_since: Time.new(2016).httpdate,
                   if_none_match: "1234")

    args = { "status" => 200,
             "headers" =>  { "Date" => "Mon, 01 Jan 2000 00:00:01 GMT",
                             "ETag" => "12345",
                             "Last-Modified" => Time.new(2015).httpdate },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)

    refute cached_response.not_modified_for?(request)
  end

  def test_modified_for_request_only_modifed_since
    request = stub(if_modified_since: Time.new(2015).httpdate,
                   if_none_match: "12345")

    args = { "status" => 200,
             "headers" =>  { "Date" => "Mon, 01 Jan 2000 00:00:01 GMT",
                             "ETag" => "12345",
                             "Last-Modified" => Time.new(2016).httpdate },
             "body" => "test body" }

    cached_response = Rack::AcornCache::CachedResponse.new(args)

    refute cached_response.not_modified_for?(request)
  end
end

class NullCachedResponseTest < Minitest::Test
  def test_fresh_for_request?
    null_cached_response = Rack::AcornCache::NullCachedResponse.new

    refute null_cached_response.fresh_for_request?("something")
  end

  def test_must_be_revalidated?
    null_cached_response = Rack::AcornCache::NullCachedResponse.new

    refute null_cached_response.must_be_revalidated?
  end

  def test_matches?
    server_response = mock('server response')
    null_cached_response = Rack::AcornCache::NullCachedResponse.new

    refute null_cached_response.matches?(server_response)
  end

  def test_update!
    null_cached_response = Rack::AcornCache::NullCachedResponse.new

    null_cached_response.update!
  end
end

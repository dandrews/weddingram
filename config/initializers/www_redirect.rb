class WwwRedirect
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    if request.host.downcase.starts_with?("weddingcrunchers.com")
      [301, {"Location" => request.url.sub("//weddingcrunchers.com", "//www.weddingcrunchers.com")}, self]
    else
      @app.call(env)
    end
  end

  def each(&block)
  end
end
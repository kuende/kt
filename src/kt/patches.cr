require "http/client"

# Needed until next release of crystal after 0.15.0
# When 204 response is returned with Content-Length=0 and no body
# it crashes in all versions <= 0.15.0

class HTTP::Client::Response
  def initialize(@status_code, @body : String? = nil, @headers : Headers = Headers.new, status_message = nil, @version = "HTTP/1.1", @body_io = nil)
   @status_message = status_message || HTTP.default_status_message_for(@status_code)

   if Response.mandatory_body?(@status_code)
     @body = "" unless @body || @body_io
   else
     if (@body || @body_io) && (headers["Content-Length"]? != "0")
       raise ArgumentError.new("status #{status_code} should not have a body")
     end
   end
 end
end

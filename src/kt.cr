require "./kt/*"
require "pool/connection"

class KT
  @host : String
  @port : Int32
  @poolsize : Int32
  @timeout : Float64

  IDENTITY_ENCODING = "text/tab-separated-values"
  BASE64_ENCODING = "text/tab-separated-values; colenc=B"

  IDENTITY_HEADERS = HTTP::Headers{"Content-Type": IDENTITY_ENCODING}
	BASE64_HEADERS = HTTP::Headers{"Content-Type": BASE64_ENCODING}
  EMPTY_HEADERS = HTTP::Headers.new

  def initialize(@host, @port, @poolsize, @timeout)
    @pool = ConnectionPool.new(capacity: @poolsize, timeout: @timeout) do
      HTTP::Client.new(@host, @port)
    end
  end

  # Count returns the number of records in the database
  def count : Int64
    status, m = do_rpc("/rpc/status", nil)
    if status != 200
      raise_error(m)
    end

    find_rec(m, "count").value.to_i64
  end

  # get retrieves the data stored at key.
  # It returns nil if no such data is found
  def get(key : String) : String?
    status, body = do_rest("GET", key, nil)

    case status
    when 200
      body
    when 404
      nil
    end
  end

  # get! retrieves the data stored at key.
  # KT::RecordNotFound is raised if not such data is found
  def get!(key : String) : String
    value = get(key)
    if value != nil
      value.not_nil!
    else
      raise KT::RecordNotFound.new("Key: #{key} not found")
    end
  end

  # get_bulk retrieves the keys in the list
  # It returns a hash of key => value.
  # If a key was not found in the database, the value in return hash will be nil
  def get_bulk(keys : Array(String)) : Hash(String, String)
    req = keys.map do |key|
      KV.new("_#{key}", "")
    end

    status, res_body = do_rpc("/rpc/get_bulk", req)

    if status != 200
      raise_error(res_body)
    end

    res = {} of String => String

    res_body.each do |kv|
      if kv.key.starts_with?('_')
        res[kv.key[1, kv.key.size - 1]] = kv.value
      end
    end

    res
  end

  # set stores the data at key
  def set(key : String, value : String)
    status, body = do_rest("PUT", key, value)

    if status != 201
      raise body
    end
  end

  # set_bulk sets multiple keys to multiple values
  def set_bulk(values : Hash(String,String)) : Int64
    req = values.map do |key, value|
      KV.new("_#{key}", value)
    end

    status, body = do_rpc("/rpc/set_bulk", req)

    if status != 200
      raise_error(body)
    end

    find_rec(body, "num").value.to_i64
  end

  # remove deletes the data at key in the database.
  def remove(key : String)
    status, body = do_rest("DELETE", key, nil)

    if status == 404
      raise KT::RecordNotFound.new
    end

    if status != 204
      raise body
    end
  end

  # remove_bulk deletes multiple keys.
  # it returnes the number of keys deleted
  def remove_bulk(keys : Array(String)) : Int64
    req = keys.map do |key|
      KV.new("_#{key}", "")
    end

    status, body = do_rpc("/rpc/remove_bulk", req)

    if status != 200
      raise_error(body)
    end

    find_rec(body, "num").value.to_i64
  end

  def do_rpc(path : String, values : Array(KV) | Nil) : Tuple(Int32, Array(KV))
    body, encoding = encode_values(values)
    headers = HTTP::Headers{"Content-Type": encoding}
    @pool.connection do |conn|
      res = conn.post(path, headers: headers, body: body)
      return res.status_code, decode_values(res.body, res.headers.get("Content-Type").join("; "))
    end
  end

  def do_rest(op : String, key : String, value : String?) : Tuple(Int32, String)
    value = "" if value.nil?
    @pool.connection do |conn|
      res = conn.exec(op, url_encode(key), headers: EMPTY_HEADERS, body: value)
      return res.status_code, res.body
    end
  end

  def find_rec(body : Array(KV), key : String) : KV
    body.each do |kv|
      if kv.key == key
        return kv
      end
    end

    KV.new("", "")
  end

  def raise_error(body : Array(KV))
    kv = find_rec(body, "ERROR")
    if kv == ""
      raise KT::Error.new("unknown error")
    end

    raise KT::Error.new("#{kv.value}")
  end

  def decode_values(body : String, content_type : String)
    # Ideally, we should parse the mime media type here,
  	# but this is an expensive operation because mime is just
  	# that awful.
  	#
  	# KT responses are pretty simple and we can rely
  	# on it putting the parameter of colenc=[BU] at
  	# the end of the string. Just look for B, U or s
  	# (last character of tab-separated-values)
  	# to figure out which field encoding is used.
    case content_type.chars.last
    when 'B'
      # base64 decode
    when 'U'
      # url decode
    when 's'
      # identity decode
    else
      raise "kt responded with unknown content-type: #{content_type}"
    end

    # Because of the encoding, we can tell how many records there
  	# are by scanning through the input and counting the \n's
    kv = body.each_line.map do |line|
      key, value = line.chomp.split("\t")
      KV.new(key, value)
    end.to_a

    kv.to_a
  end

  def url_encode(key : String) : String
    "/" + URI.escape(key)
  end

  def encode_values(kv : Array(KV))
    has_binary = kv.any? do |kv|
      has_binary?(kv.key) || has_binary?(kv.value)
    end

    str = String.build do |str|
      kv.each do |kv|
        if has_binary
          str << Base64.strict_encode(kv.key)
          str << "\t"
          str << Base64.strict_encode(kv.value)
        else
          str << kv.key
          str << "\t"
          str << kv.value
        end
        str << "\n"
      end
    end

    encoding = has_binary ? BASE64_ENCODING : IDENTITY_ENCODING

    {str, encoding}
  end

  def encode_values(kv : Nil)
    {"", IDENTITY_ENCODING}
  end

  def has_binary?(value : String) : Bool
    value.bytes.any? do |c|
      c < 0x20 || c > 0x7e
    end
  end
end

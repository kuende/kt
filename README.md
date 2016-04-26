# KT

Crystal bindings for [Kyoto Tycoon](http://fallabs.com/kyototycoon/). It uses a connection pool to maintain multiple connections.

## Installation


Add this to your application's `shard.yml`:

```yaml
dependencies:
  kt:
    github: kuende/kt
```


## Usage

```crystal
require "kt"

kt = KT.new(host: "127.0.0.1", port: 1978, poolsize: 5, timeout: 5.0)

# Setting
kt.set("japan", "tokyo") # set a key
kt.set_bulk({"china": "beijing", "france": "paris", "uk": "london"})

kt.get("japan") # => "tokyo"
kt.get_bulk(["japan", "france"]) # => {"japan": "tokyo", "france": "paris"}
kt.get("foo") # => nil
kt.get!("foo") # => raises KT::RecordNotFound

kt.remove("japan") # => true
kt.remove("japan") # => false, key japan is not found anymore
kt.remove!("japan") # => raises KT::RecordNotFound becouse key japan is not found
kt.remove_bulk(["japan", "china"]) # => 1 (number keys deleted)

kt.clear # deletes all records in the database

kt.set_bulk({"user:1": "1", "user:2": "2", "user:4": "4"})
kt.match_prefix("user:") => ["user:1", "user:2", "user:3", "user:4", "user:5"]

# Compare and swap
kt.set("user:1", "1")
kt.cas("user:1", "1", "2") => true
kt.cas("user:1", "1", "3") => false, previous value is "2"
kt.cas("user:1", nil, "3") => false, record already exists with value "2"
kt.cas("user:2", nil, "1") => true, no record exists so it was set
kt.cas("user:1", "2", nil) => true, record is removed becouse it was present
kt.cas("user:1", "2", nil) => false, it fails becouse no record with this key exists

# cas! raises where cas returns false
kt.cas!("user:1", "1", "2") => KT::CASFailed, no record exists with this value

kt.count # => 2 keys in database
```

## Contributing

1. Fork it ( https://github.com/kuende/kt/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

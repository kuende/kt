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

kt.count # => 2 keys in database
```

## Contributing

1. Fork it ( https://github.com/kuende/kt/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

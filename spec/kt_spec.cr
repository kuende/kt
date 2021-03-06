require "./spec_helper"

HOST = "127.0.0.1"
PORT = 1979

cmd = start_server(HOST, PORT)
kt = KT.new(host: HOST, port: PORT, poolsize: 5, timeout: 5.0)

at_exit do
  stop_server(cmd)
end

describe KT do
  describe "count" do
    it "returns 0 by default" do
      kt.count.should eq(0)
    end

    it "returns 2 after some keys were inserted" do
      kt.set("japan", "tokyo")
      kt.set("china", "beijing")

      kt.count.should eq(2)
    end
  end

  describe "get/set/remove" do
    it "sets a few keys then it gets them" do
      ["a", "b", "c"].each do |k|
        kt.set(k, k + "aaa")
        kt.get(k).should eq(k + "aaa")
      end
    end

    it "removes a key" do
      kt.set("to/be/removed", "42")
      kt.remove("to/be/removed")
      kt.get("to/be/removed").should eq(nil)
    end

    it "get returns nil if not found" do
      kt.get("not/existing").should eq(nil)
    end

    describe "get!" do
      it "returns a string if existing" do
        kt.set("foo", "bar")
        kt.get("foo").should eq("bar")
      end

      it "raises error if not found" do
        expect_raises(KT::RecordNotFound) do
          kt.get!("not/existing")
        end
      end
    end

    describe "remove" do
      it "returns true if key was deleted" do
        kt.set("foo", "bar")
        kt.remove("foo").should eq(true)
      end

      it "returns false if key was not found" do
        kt.remove("not/existing").should eq(false)
      end
    end

    describe "remove!" do
      it "returns nothing if key was deleted" do
        kt.set("foo", "bar")
        kt.remove("foo")
        kt.get("foo").should eq(nil)
      end

      it "raises error if not found" do
        expect_raises(KT::RecordNotFound) do
          kt.remove!("not/existing")
        end
      end
    end
  end

  describe "bulk" do
    it "returns nil hash for not found keys" do
      kt.get_bulk(["foo1", "foo2", "foo3"]).should eq({} of String => String)
    end

    it "returns hash with key value" do
      expected = {
        "cache/news/1" => "1",
        "cache/news/2" => "2",
        "cache/news/3" => "3",
        "cache/news/4" => "4",
        "cache/news/5" => "5",
        "cache/news/6" => "6"
      }
      expected.each do |k, v|
        kt.set(k, v)
      end

      kt.get_bulk(expected.keys).should eq(expected)
    end

    it "returns hash with found elements" do
      kt.set("foo4", "4")
      kt.set("foo5", "5")

      kt.get_bulk(["foo4", "foo5", "foo6"]).should eq({"foo4" => "4", "foo5" => "5"})
    end

    it "set_bulk sets multiple keys" do
      kt.set_bulk({"foo7" => "7", "foo8" => "8", "foo9" => "9"})
      kt.get_bulk(["foo7", "foo8", "foo9"]).should eq({"foo7" => "7", "foo8" => "8", "foo9" => "9"})
    end

    it "remove_bulk deletes bulk items" do
      kt.set_bulk({"foo7" => "7", "foo8" => "8", "foo9" => "9"})
      kt.remove_bulk(["foo7", "foo8", "foo9"])
      kt.get_bulk(["foo7", "foo8", "foo9"]).should eq({} of String => String)
    end

    it "returns the number of keys deleted" do
      kt.set_bulk({"foo7" => "7", "foo8" => "8", "foo9" => "9"})
      kt.remove_bulk(["foo7", "foo8", "foo9", "foo1000"]).should eq(3)
    end
  end

  describe "match_prefix" do
    it "returns nothing for not found prefix" do
      kt.match_prefix("user:", 100).should eq([] of String)
    end

    it "returns correct results sorted" do
      kt.set_bulk({"user:1" => "1", "user:2" => "2", "user:4" => "4"})
      kt.set_bulk({"user:3" => "3", "user:5" => "5"})
      kt.set_bulk({"usera" => "aaa", "users:bbb" => "bbb"})

      kt.match_prefix("user:").should eq(["user:1", "user:2", "user:3", "user:4", "user:5"])
      # It returns the results in random order
      kt.match_prefix("user:", 2).size.should eq(2)
    end
  end

  describe "clear" do
    it "clears the database" do
      kt.count.should_not eq(0)
      kt.clear
      kt.count.should eq(0)
    end
  end

  describe "cas" do
    describe "with old and new" do
      it "sets new value if old value is correct and returns true" do
        kt.set("cas:1", "1")
        kt.cas("cas:1", "1", "2").should eq(true)
        kt.get("cas:1").should eq("2")
      end

      it "returns false if old value is not equal" do
        kt.set("cas:2", "3")
        kt.cas("cas:2", "1", "2").should eq(false)
        kt.get("cas:2").should eq("3")
      end
    end

    describe "without old value" do
      it "sets the value if no record exists in db and returns true" do
        kt.cas("cas:3", nil, "5").should eq(true)
        kt.get("cas:3").should eq("5")
      end

      it "returns false if record exists in db" do
        kt.set("cas:4", "2")
        kt.cas("cas:4", nil, "5").should eq(false)
        kt.get("cas:4").should eq("2")
      end
    end

    describe "without new value" do
      it "removes record if it exists in db and returns true" do
        kt.set("cas:5", "1")
        kt.cas("cas:5", "1", nil).should eq(true)
        kt.get("cas:5").should eq(nil)
      end

      it "returns false if no record exists in db" do
        kt.cas("cas:6", "1", nil).should eq(false)
        kt.get("cas:6").should eq(nil)
      end
    end
  end

  describe "cas" do
    describe "with old and new" do
      it "sets new value if old value is correct" do
        kt.set("cas!:1", "1")
        kt.cas!("cas!:1", "1", "2")
        kt.get("cas!:1").should eq("2")
      end

      it "raises error if old value is not equal" do
        kt.set("cas!:2", "3")
        expect_raises(KT::CASFailed) do
          kt.cas!("cas!:2", "1", "2")
        end
        kt.get("cas!:2").should eq("3")
      end
    end

    describe "without old value" do
      it "sets the value if no record exists in db" do
        kt.cas!("cas!:3", nil, "5")
        kt.get("cas!:3").should eq("5")
      end

      it "raises error if record exists in db" do
        kt.set("cas!:4", "2")
        expect_raises(KT::CASFailed) do
          kt.cas!("cas!:4", nil, "5")
        end
        kt.get("cas!:4").should eq("2")
      end
    end

    describe "without new value" do
      it "removes record if it exists in db" do
        kt.set("cas!:5", "1")
        kt.cas!("cas!:5", "1", nil)
        kt.get("cas!:5").should eq(nil)
      end

      it "raises error if no record exists in db" do
        expect_raises(KT::CASFailed) do
          kt.cas!("cas!:6", "1", nil)
        end
        kt.get("cas!:6").should eq(nil)
      end
    end
  end

  describe "binary" do
    it "sets binary and gets it" do
      kt.set_bulk({"Café" => "foo"})
      kt.get("Café").should eq("foo")

      kt.set_bulk({"foo" => "Café"})
      kt.get_bulk(["foo"]).should eq({"foo" => "Café"})
    end

    it "sets string using newlines and gets it" do
      kt.set_bulk({"foo" => "my\n\ttest"})
      kt.get_bulk(["foo"]).should eq({"foo" => "my\n\ttest"})
    end
  end
end

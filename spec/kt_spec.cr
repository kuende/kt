require "./spec_helper"

HOST = "127.0.0.1"
PORT = 1979

cmd = start_server(HOST, PORT)
kt = KT.new(HOST, PORT)

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

  describe "get/set" do
    it "sets a few keys then it gets them" do
      ["a", "b", "c"].each do |k|
        kt.set(k, k + "aaa")
        kt.get(k).should eq(k + "aaa")
      end
    end
  end

  describe "bulk" do
    it "returns nil hash for not found keys" do
      kt.get_bulk(["foo1", "foo2", "foo3"]).should eq({} of String => String)
    end

    it "returns hash with key value" do
      expected = {
        "cache/news/1": "1",
    		"cache/news/2": "2",
    		"cache/news/3": "3",
    		"cache/news/4": "4",
    		"cache/news/5": "5",
    		"cache/news/6": "6"
      }
      expected.each do |k, v|
        kt.set(k, v)
      end

      kt.get_bulk(expected.keys).should eq(expected)
    end

    it "returns hash with found elements" do
      kt.set("foo4", "4")
      kt.set("foo5", "5")

      kt.get_bulk(["foo4", "foo5", "foo6"]).should eq({"foo4": "4", "foo5": "5"})
    end

    it "set_bulk sets multiple keys" do
      kt.set_bulk({"foo7": "7", "foo8": "8", "foo9": "9"})
      kt.get_bulk(["foo7", "foo8", "foo9"]).should eq({"foo7": "7", "foo8": "8", "foo9": "9"})
    end

    it "remove_bulk deletes bulk items" do
      kt.set_bulk({"foo7": "7", "foo8": "8", "foo9": "9"})
      kt.remove_bulk(["foo7", "foo8", "foo9"])
      kt.get_bulk(["foo7", "foo8", "foo9"]).should eq({} of String => String)
    end

    it "returns the number of keys deleted" do
      kt.set_bulk({"foo7": "7", "foo8": "8", "foo9": "9"})
      kt.remove_bulk(["foo7", "foo8", "foo9", "foo1000"]).should eq(3)
    end
  end
end

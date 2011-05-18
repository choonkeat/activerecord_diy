# encoding: utf-8
require 'spec_helper'

describe ActiverecordDIY::Json::Backed do
  before(:each) do
    ActiveRecord::Base.connection.execute "DROP TABLE test_models" rescue nil
    class TestModel < ActiveRecord::Base
      use_json_attributes do |t|
        t.column :k1, :string
        t.integer :k2, :k3
        t.datetime :time_at
      end
    end
  end
  after(:each) do
    Object.send(:remove_const, "TestModel")
    ActiveRecord::Base.connection.execute "DROP TABLE test_models"
  end
  it "should create table automatically" do
    ActiveRecord::Base.connection.tables.should include("test_models")
  end
  it "should have minimal schema (guid, json, timestamps)" do
    TestModel.column_names.should == ["guid", "json", "created_at", "updated_at"]
  end
  it "should assign guid when not given" do
    object = TestModel.new :k1 => "hello"
    object.save!
    object.guid.should_not be_nil
  end
  it "should use guid if provided", :guid => true do
    preset_guid = Time.now.to_f.to_s
    object = TestModel.new :k1 => "hello"
    object.guid = preset_guid
    object.save!
    object.guid.should == preset_guid
  end
  context "columns" do
    before(:each) do
      @instance = TestModel.create!(:k1 => "i am string", :k2 => 2, :k3 => 9223372036854775807, :time_at => Time.now)
      @db = TestModel.find(@instance.id)
    end
    after(:each) do
      @instance.destroy
    end
    it "should return datetime attributes as Time" do
      @instance.time_at.class.should == Time
      @db.time_at.class.should == Time
    end
    it "should return integer attributes as Fixnum/Bignum" do
      @instance.k2.class.should == Fixnum
      @db.k2.class.should == Fixnum
      @instance.k3.class.should == Bignum
      @db.k3.class.should == Bignum
    end
    it "should return string attributes as String" do
      @instance.k1.class.should == String
      @db.k1.class.should == String
    end
  end
end
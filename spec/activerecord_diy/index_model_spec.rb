# encoding: utf-8
require 'spec_helper'

def debug_sql_when
  lg = ActiveRecord::Base.logger
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  yield ActiveRecord::Base.logger
ensure
  ActiveRecord::Base.logger = lg
end

describe ActiverecordDIY::Index::Model do
  context "when source table" do
    before(:each) do
      Delayed::Job.delete_all
      class TestModel < ActiveRecord::Base
        use_json_attributes do |t|
          t.column :k0, :string
          t.column :k1, :string
          t.column :k2, :integer
          t.column :k3, :datetime
        end
      end
      Delayed::Job.count.should == 0
      class CreatedAtIndex < ActiveRecord::Base; set_table_name "test_models_created_at"; end
      class CreatedK2Index < ActiveRecord::Base; set_table_name "test_models_created_at_k2"; end
      class K1K2Index < ActiveRecord::Base; set_table_name "test_models_k1_k2"; end
      class K2Index < ActiveRecord::Base; set_table_name "test_models_k2"; end
      class DataTable < ActiveRecord::Base; set_table_name "test_models"; end
    end
    after(:each) do
      TestModel.drop_index_tables
      Object.send(:remove_const, "TestModel")
      ActiveRecord::Base.connection.execute "DROP TABLE test_models"
    end
    context "is initially empty" do
      before(:each) do
        TestModel.use_index_tables do |t|
          t.indexes_for :created_at
          t.indexes_for :k1, :k2
          t.indexes_for :created_at, :k0, :k2
        end
        Delayed::Job.count.should > 1
        Delayed::Job.all.collect {|j| j.payload_object.perform}
      end
      it "should have empty index table" do
        TestModel.count.should == 0
        TestModel.count.should == CreatedAtIndex.count
      end
      it "should add a row into index table for every row of data added" do
        TestModel.create!(:k1 => "hello", :k2 => rand(999))
        TestModel.count.should == 1
        TestModel.count.should == CreatedAtIndex.count
      end
    end
    context "is already populated" do
      before(:each) do
        @initial_created_at = 1.minute.ago
        @last_created_at = @initial_created_at-1
        @timestamp = Time.parse("2011-05-16")
        ['a','b','c'].each do |k1|
          [1, 2, 3].each do |k2|
            TestModel.create!(:k0 => "hello", :k1 => k1, :k2 => k2, :k3 => @timestamp, :created_at => (@last_created_at+=1))
          end
        end
        TestModel.use_index_tables do |t|
          t.indexes_for :created_at
          t.indexes_for :created_at, :k2
          t.indexes_for :k1, :k2
          t.indexes_for :k2
        end
        Delayed::Job.count.should > 1
      end
      it "data table should count > 0 " do
        TestModel.count.should > 0
      end
      it "index table should count == 0 " do
        CreatedAtIndex.count.should == 0
      end
      context "Delayed::Job" do
        before(:each) do
          @job_count = Delayed::Job.count
          Delayed::Job.all.collect {|j| j.payload_object.per_page=1; j.payload_object.perform}
        end
        it "should queue another job when per_page is not enough to populate all rows" do
          Delayed::Job.count.should == @job_count*2
        end
        it "should populate most recent data first" do
          CreatedAtIndex.count.should == 1
          CreatedAtIndex.first.created_at == @last_created_at
          CreatedAtIndex.where(:created_at => @initial_created_at).first.should be_false
          TestModel.order("created_at ASC").first.created_at.to_i.should == @last_created_at.to_i
          TestModel.order("created_at ASC").first.created_at.to_i.should_not == @initial_created_at.to_i
        end
      end
      context "after Delayed::Job is completed" do
        before(:each) do
          @job_count = Delayed::Job.count
          Delayed::Job.all.collect {|j| j.payload_object.perform}
        end
        it "should not queue another job when per_page is enough to populate all rows" do
          Delayed::Job.count.should == @job_count
        end
        it "index table should count == data table count" do
          CreatedAtIndex.count.should == TestModel.count
          CreatedAtIndex.where(:created_at => @initial_created_at).first.should be_true
          TestModel.order("created_at ASC").first.created_at.to_i.should == @initial_created_at.to_i
          TestModel.order("created_at DESC").first.created_at.to_i.should == @last_created_at.to_i
        end
        [["maximum", 3, nil], ["minimum", 1, nil], ["average", 2, nil], ["count", 9, 0]].each do |aggregate_function, result, result2|
          context aggregate_function do
            context "when scope does not have index table" do
              it "should raise error" do
                lambda { TestModel.send(aggregate_function, "k2") }.should_not raise_error
                lambda { TestModel.send(aggregate_function, "k3") }.should raise_error
              end
            end
            context "when scope uses index" do
              before(:each) do
                @scope = TestModel.where("created_at > 0")
              end
              it "should calculate #{aggregate_function.upcase}= #{result.inspect}" do
                @scope.send(aggregate_function, "k2").should == result
              end
              it "should calculate #{aggregate_function.upcase}= #{result.inspect} even when data table is emptied" do
                TestModel.delete_all
                @scope.send(aggregate_function, "k2").should == result
              end
              it "should calculate #{aggregate_function.upcase}= #{result2.inspect} when index table is emptied" do
                CreatedK2Index.delete_all
                @scope.send(aggregate_function, "k2").should == result2
              end
            end
            context "when no explicit scope is used", :model_aggregate => true do
              it "should calculate #{aggregate_function.upcase}= #{result.inspect}" do
                TestModel.send(aggregate_function, "k2").should == result
              end
              it "should calculate #{aggregate_function.upcase}= #{result.inspect} even when data table is emptied" do
                TestModel.delete_all
                TestModel.send(aggregate_function, "k2").should == result
              end
              it "should calculate #{aggregate_function.upcase}= #{result2.inspect} when index table is emptied" do
                K2Index.delete_all
                TestModel.send(aggregate_function, "k2").should == result2
              end
            end
          end
        end
      end
    end
  end
  context "reusing same scope object", :reuse => true do
    before(:all) do
      Delayed::Job.delete_all
      class TestModel < ActiveRecord::Base
        use_json_attributes do |t|
          t.column :k0, :string
          t.column :k1, :string
          t.column :k2, :integer
          t.column :k3, :datetime
        end
        use_index_tables do |t|
          t.indexes_for :k0, :k2
          t.indexes_for :k0, :k2, :k3
        end
      end
      @initial_created_at = 1.minute.ago
      @last_created_at = @initial_created_at
      @timestamp = Time.parse("2011-05-16")
      ['a','b','c'].each do |k1|
        [1, 2, 3].each do |k2|
          TestModel.create!(:k0 => "hello", :k1 => k1, :k2 => k2, :k3 => @timestamp, :created_at => (@last_created_at+=1))
        end
      end
      Delayed::Job.count.should > 1
      Delayed::Job.all.collect {|j| j.payload_object.perform}
      @scope = TestModel.where(:k0 => "hello")
    end
    after(:all) do
      TestModel.drop_index_tables
      Object.send(:remove_const, "TestModel")
      ActiveRecord::Base.connection.execute "DROP TABLE test_models"
    end
    it "should MAX(k2) ON `test_models_k0_k2` should be 3" do
      @scope.maximum('k2').should == 3
    end
    it "should MAX(k2) ON `test_models_k0_k2_k3` should be 3" do
      @scope.where(:k3 => @timestamp).maximum('k2').should == 3
    end
  end
end

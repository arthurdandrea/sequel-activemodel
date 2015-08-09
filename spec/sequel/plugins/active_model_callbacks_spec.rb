require 'spec_helper'
require 'sequel/plugins/active_model_callbacks'
require 'sequel/plugins/active_model'
describe Sequel::Plugins::ActiveModelCallbacks do
  let(:db) do
    db = Sequel.sqlite
    db.execute "CREATE TABLE tablename(a,b);"
    db
  end

  let(:model) do
    model = Class.new(Sequel.Model(db[:tablename]))
    model.plugin :active_model_callbacks
    model
  end

  it 'loads :active_model plugin' do
    model
    expect(model.plugins).to include Sequel::Plugins::ActiveModel
  end

  describe 'before_save' do
    it "calls the block when #save is called" do
      callback = double("callback")

      model.before_save do callback.call end

      expect(callback).to receive(:call).once
      model.new.save
    end

    it "calls the method when #save is called" do
      callback = double("callback")

      model.send :define_method, :before_save_callback do callback.call end
      model.before_save :before_save_callback

      expect(callback).to receive(:call).once
      model.new.save
    end
  end

  describe 'after_save' do
    it "calls the block when #save is called" do
      callback = double("callback")

      model.after_save do callback.call end

      expect(callback).to receive(:call).once
      model.new.save
    end

    it "calls the method when #save is called" do
      callback = double("callback")

      model.send :define_method, :after_save_callback do callback.call end
      model.after_save :after_save_callback

      expect(callback).to receive(:call).once
      model.new.save
    end
  end
end

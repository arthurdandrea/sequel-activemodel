require 'spec_helper'

describe Sequel::Plugins::ActiveModelValidations do
  let(:model) do
    model = Class.new(Sequel::Model)
    model.plugin :active_model_validations
    model
  end

  # filter out the Sequel::Model from the plugins Array
  # it is causing trouble with rspec beautiful error generation
  let(:plugins) do
    model.plugins.select do |plugin| plugin != Sequel::Model end
  end

  it 'loads the :active_model plugin' do
    expect(plugins).to include(Sequel::Plugins::ActiveModel)
  end

  it 'loads the :active_model_callbacks plugin' do
    expect(plugins).to include(Sequel::Plugins::ActiveModelCallbacks)
  end

  it 'loads the :active_model_translations plugin' do
    expect(plugins).to include(Sequel::Plugins::ActiveModelTranslations)
  end
end

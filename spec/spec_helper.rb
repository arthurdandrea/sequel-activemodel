$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sequel'
require 'sequel/activemodel'
require 'sequel/plugins/active_model' # preload
require 'sequel/plugins/active_model_callbacks'
require 'sequel/plugins/active_model_translations'
require 'sequel/plugins/active_model_validations'

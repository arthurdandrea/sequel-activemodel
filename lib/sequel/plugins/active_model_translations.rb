require 'active_model'

module Sequel
  module Plugins
    module ActiveModelTranslations
      def self.apply(model)
        model.plugin :active_model
      end

      module ClassMethods
        include ::ActiveModel::Translation

        # Set the i18n scope to overwrite ActiveModel.
        def i18n_scope #:nodoc:
          :sequel
        end

        def lookup_ancestors #:nodoc:
          self.ancestors.select do |x| x.respond_to?(:model_name) end
        end
      end
    end
  end
end

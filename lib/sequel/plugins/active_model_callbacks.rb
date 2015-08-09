require 'active_model'

module Sequel
  module Plugins
    module ActiveModelCallbacks
      def self.apply(model, *args)
        model.plugin :active_model
        model.extend ::ActiveModel::Callbacks
        model.define_model_callbacks(:save, :create, :update, :destroy)
        model.define_callbacks(:validation,
                         terminator: ->(_,result) { result == false },
                         skip_after_callbacks_if_terminated: true,
                         scope: [:kind, :name])
      end

      module InstanceMethods
        def around_save
          run_callbacks(:save) do
            super
          end
        end

        def around_create
          run_callbacks(:create) do
            super
          end
        end

        def around_update
          run_callbacks(:update) do
            super
          end
        end

        def around_validation
          run_callbacks(:validation) do
            super
          end
        end

        def around_destroy
          run_callbacks(:destroy) do
            super
          end
        end

      end # InstanceMethods

      module ClassMethods
        # Defines a callback that will get called right before validation
        # happens.
        #
        #   class Person < Sequel::Model
        #     plugin :active_model_callbacks
        #     plugin :active_model_validations
        #
        #     validates_length_of :name, maximum: 6
        #
        #     before_validation :remove_whitespaces
        #
        #     private
        #
        #     def remove_whitespaces
        #       name.strip!
        #     end
        #   end
        #
        #   person = Person.new
        #   person.name = '  bob  '
        #   person.valid? # => true
        #   person.name   # => "bob"
        def before_validation(*args, &block)
          options = args.last
          if options.is_a?(Hash) && options[:on]
            options[:if] = Array(options[:if])
            options[:on] = Array(options[:on])
            options[:if].unshift lambda { |o|
              options[:on].include? o.validation_context
            }
          end
          set_callback(:validation, :before, *args, &block)
        end

        # Defines a callback that will get called right after validation
        # happens.
        #
        #   class Person < Sequel::Model
        #     plugin :active_model_callbacks
        #     plugin :active_model_validations
        #     validates_presence_of :name
        #
        #     after_validation :set_status
        #
        #     private
        #
        #     def set_status
        #       self.status = errors.empty?
        #     end
        #   end
        #
        #   person = Person.new
        #   person.name = ''
        #   person.valid? # => false
        #   person.status # => false
        #   person.name = 'bob'
        #   person.valid? # => true
        #   person.status # => true
        def after_validation(*args, &block)
          options = args.extract_options!
          options[:prepend] = true
          options[:if] = Array(options[:if])
          if options[:on]
            options[:on] = Array(options[:on])
            options[:if].unshift("#{options[:on]}.include? self.validation_context")
          end
          set_callback(:validation, :after, *(args << options), &block)
        end
      end # ClassMethods

    end # ActiveModelCallbacks
  end # Plugins
end # Sequel

require 'active_model'

module Sequel::Validations
  def self.const_missing(name)
    begin
      const = ActiveModel::Validations.const_get(name)
    rescue NameError
      const = super
    end
    const_set(name, const)
    const
  end

  class UniquenessValidator < ActiveModel::EachValidator
    def initialize(options)
      super(options.reverse_merge(case_sensitive: true))
    end

    def validate_each(record, attribute, value)
      arr = Array.wrap(attribute)
      arr.concat Array.wrap(options[:scope])
      return if options[:only_if_modified] && !record.new? && !arr.any? { |x| record.changed_columns.include?(x) }
      ds = record.model.filter(arr.map { |x| [x, record.send(x)] })
      ds = ds.exclude(record.pk_hash) unless record.new?

      if ds.count > 0
        record.errors.add(attribute, :taken, options.except(:case_sensitive, :scope).merge(value: value))
      end
    end
  end
end

module Sequel::Plugins::ActiveModelValidations
  def self.apply(model, *args)
    model.plugin :active_model_callbacks
    model.plugin :active_model_translations
    model.define_callbacks :validate, scope: :name
    model.class_eval do
      @validation_reflections = Hash.new { |h,k| h[k] = [] }
    end
    model.extend ::ActiveModel::Validations::HelperMethods
  end

  module InstanceMethods
    def errors
      @errors ||= ::ActiveModel::Errors.new(self)
    end

    def validate
      super
      run_callbacks :validate
    end

    def invalid?
      !valid?
    end

    def read_attribute_for_validation(attr)
      send(attr)
    end
  end

  module ClassMethods
    Sequel::Plugins.inherited_instance_variables(self, :@validation_reflections => proc { |oldval|
      newval = Hash.new { |h, k| h[k] = [] }
      oldval.each { |k,v| newval[k] = v.map(&:dup) }
      newval
    })

    attr_reader :validation_reflections

    # Adds a validation method or block to the class. This is useful when
    # overriding the +validate+ instance method becomes too unwieldy and
    # you're looking for more descriptive declaration of your validations.
    #
    # This can be done with a symbol pointing to a method:
    #
    #   class Comment
    #     include ActiveModel::Validations
    #
    #     validate :must_be_friends
    #
    #     def must_be_friends
    #       errors.add(:base, "Must be friends to leave a comment") unless commenter.friend_of?(commentee)
    #     end
    #   end
    #
    # With a block which is passed with the current record to be validated:
    #
    #   class Comment
    #     include ActiveModel::Validations
    #
    #     validate do |comment|
    #       comment.must_be_friends
    #     end
    #
    #     def must_be_friends
    #       errors.add(:base, "Must be friends to leave a comment") unless commenter.friend_of?(commentee)
    #     end
    #   end
    #
    # Or with a block where self points to the current record to be validated:
    #
    #   class Comment
    #     include ActiveModel::Validations
    #
    #     validate do
    #       errors.add(:base, "Must be friends to leave a comment") unless commenter.friend_of?(commentee)
    #     end
    #   end
    #
    def validate(*args, &block)
      options = args.extract_options!
      if options.key?(:on)
        options = options.dup
        options[:if] = Array.wrap(options[:if])
        options[:if].unshift("validation_context == :#{options[:on]}")
      end
      args << options
      set_callback(:validate, *args, &block)
    end

    def validates_with(*args, &block)
      options = args.extract_options!
      args.each do |klass|
        options[:class] = self
        validator = klass.new(options, &block)
        validator.setup(self) if validator.respond_to?(:setup)

        if validator.respond_to?(:attributes) && !validator.attributes.empty?
          validator.attributes.each do |attribute|
            @validation_reflections[attribute.to_sym] << validator
          end
        else
          @validation_reflections[nil] << validator
        end

        validate(validator, options)
      end
    end

    # Validates whether the value of the specified attributes are unique across the system.
    # Useful for making sure that only one user
    # can be named "davidhh".
    #
    #   class Person < Sequel::Model
    #     plugin :active_model_validations
    #     validates_uniqueness_of :user_name
    #   end
    #
    # It can also validate whether the value of the specified attributes are unique based on a scope parameter:
    #
    #   class Person < Sequel::Model
    #     plugin :active_model_validations
    #     validates_uniqueness_of :user_name, :scope => :account_id
    #   end
    #
    # Or even multiple scope parameters.  For example, making sure that a teacher can only be on the schedule once
    # per semester for a particular class.
    #
    #   class TeacherSchedule < Sequel::Model
    #     plugin :active_model_validations
    #     validates_uniqueness_of :teacher_id, :scope => [:semester_id, :class_id]
    #   end
    #
    # When the record is created, a check is performed to make sure that no record exists in the database
    # with the given value for the specified attribute (that maps to a column). When the record is updated,
    # the same check is made but disregarding the record itself.
    #
    # Configuration options:
    # * <tt>:message</tt> - Specifies a custom error message (default is: "has already been taken").
    # * <tt>:scope</tt> - One or more columns by which to limit the scope of the uniqueness constraint.
    # * <tt>:case_sensitive</tt> - Looks for an exact match. Ignored by non-text columns (+true+ by default).
    # * <tt>:allow_nil</tt> - If set to true, skips this validation if the attribute is +nil+ (default is +false+).
    # * <tt>:allow_blank</tt> - If set to true, skips this validation if the attribute is blank (default is +false+).
    # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
    #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).
    #   The method, proc or string should return or evaluate to a true or false value.
    # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
    #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or
    #   <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).  The method, proc or string should
    #   return or evaluate to a true or false value.
    #
    def validates_uniqueness_of(*attr_names)
      validates_with Sequel::Validations::UniquenessValidator, _merge_attributes(attr_names)
    end

    # This method is a shortcut to all default validators and any custom
    # validator classes ending in 'Validator'. Note that Rails default
    # validators can be overridden inside specific classes by creating
    # custom validator classes in their place such as PresenceValidator.
    #
    # Examples of using the default rails validators:
    #
    #   validates :terms, :acceptance => true
    #   validates :password, :confirmation => true
    #   validates :username, :exclusion => { :in => %w(admin superuser) }
    #   validates :email, :format => { :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :on => :create }
    #   validates :age, :inclusion => { :in => 0..9 }
    #   validates :first_name, :length => { :maximum => 30 }
    #   validates :age, :numericality => true
    #   validates :username, :presence => true
    #   validates :username, :uniqueness => true
    #
    # The power of the +validates+ method comes when using custom validators
    # and default validators in one call for a given attribute e.g.
    #
    #   class EmailValidator < ActiveModel::EachValidator
    #     def validate_each(record, attribute, value)
    #       record.errors[attribute] << (options[:message] || "is not an email") unless
    #         value =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
    #     end
    #   end
    #
    #   class Person < Sequel::Model
    #     plugin :active_model_validations
    #     attr_accessor :name, :email
    #
    #     validates :name, :presence => true, :uniqueness => true, :length => { :maximum => 100 }
    #     validates :email, :presence => true, :email => true
    #   end
    #
    # Validator classes may also exist within the class being validated
    # allowing custom modules of validators to be included as needed e.g.
    #
    #   class Film < Sequel::Model
    #     plugin :active_model_validations
    #
    #     class TitleValidator < ActiveModel::EachValidator
    #       def validate_each(record, attribute, value)
    #         record.errors[attribute] << "must start with 'the'" unless value =~ /\Athe/i
    #       end
    #     end
    #
    #     validates :name, :title => true
    #   end
    #
    # Additionally validator classes may be in another namespace and still used within any class.
    #
    #   validates :name, :'file/title' => true
    #
    # The validators hash can also handle regular expressions, ranges,
    # arrays and strings in shortcut form, e.g.
    #
    #   validates :email, :format => /@/
    #   validates :gender, :inclusion => %w(male female)
    #   validates :password, :length => 6..20
    #
    # When using shortcut form, ranges and arrays are passed to your
    # validator's initializer as +options[:in]+ while other types including
    # regular expressions and strings are passed as +options[:with]+
    #
    # Finally, the options +:if+, +:unless+, +:on+, +:allow_blank+ and +:allow_nil+ can be given
    # to one specific validator, as a hash:
    #
    #   validates :password, :presence => { :if => :password_required? }, :confirmation => true
    #
    # Or to all at the same time:
    #
    #   validates :password, :presence => true, :confirmation => true, :if => :password_required?
    #
    def validates(*attributes)
      defaults = attributes.extract_options!
      validations = defaults.slice!(*_validates_default_keys)

      raise ArgumentError, "You need to supply at least one attribute" if attributes.empty?
      raise ArgumentError, "You need to supply at least one validation" if validations.empty?

      defaults.merge!(attributes: attributes)

      validations.each do |key, options|
        key = "#{key.to_s.camelize}Validator"

        begin
          validator = key.include?('::') ? key.constantize : Sequel::Validations.const_get(key)
        rescue NameError
          raise ArgumentError, "Unknown validator: '#{key}'"
        end

        validates_with(validator, defaults.merge(_parse_validates_options(options)))
      end
    end

    protected

    # When creating custom validators, it might be useful to be able to specify
    # additional default keys. This can be done by overwriting this method.
    def _validates_default_keys
      [ :if, :unless, :on, :allow_blank, :allow_nil ]
    end

    def _parse_validates_options(options) #:nodoc:
      case options
      when TrueClass
        {}
      when Hash
        options
      when Range, Array
        { in: options }
      else
        { with: options }
      end
    end
  end
end

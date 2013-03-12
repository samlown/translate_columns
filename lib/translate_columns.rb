# encoding: utf-8
#
# TranslateColumns
# 
# Copyright (c)2007-2011 Samuel Lown <me@samlown.com>
# 
module TranslateColumns
 
  class MissingParent < StandardError
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  # methods used in the class definition
  module ClassMethods
         
    # Read the provided list of symbols as column names and 
    # generate methods for each to access translated versions.
    # 
    # Possible options, after the columns, include:
    # 
    # * :locale_field - Name of the field in the parents translation table
    # of the locale. This defaults to 'locale'.
    #
    def translate_columns( *options )
   
      locale_field = 'locale'
      
      columns = [ ]
      if ! options.is_a? Array
        raise "Provided parameter to translate_columns is not an array!"
      end
      # extract all the options
      options.each do | opt |
        if opt.is_a? Symbol
          columns << opt
        elsif opt.is_a? Hash
          # Override the locale class if set.
          locale_field = opt[:locale_field]
        end
      end

      define_method 'columns_to_translate' do
        columns.collect{ |c| c.to_s }
      end
      
      # set the instance Methods first
      include TranslateColumns::InstanceMethods
      
      # Rails magic to override the normal save process
      alias_method_chain :save, :translation
      alias_method_chain :save!, :translation
      alias_method_chain :attributes=, :locale

      # Generate a module containing methods that override access 
      # to the ActiveRecord methods.
      # This dynamic module is then included in the parent such that
      # the super method will function correctly.
      mod = Module.new do | m |
        
        columns.each do | column |

          next if ['id', locale_field].include?(column.to_s)
        
          # This is strange, so allow me to explain:
          #  We define access to the original method and its super,
          #  a normal "alias" can't find the super which is the method
          #  created by ActionBase.
          #  The Alias_method function takes a copy, and retains the 
          #  ability to call the parent with the same name.
          #  Finally, the method is overwritten to support translation.
          #  
          #  All this is to avoid defining parameters for the overwritten
          #  accessor which normally doesn't have them.
          #  (Warnings are produced on execution when a metaprogrammed
          #  function is called without parameters and its expecting them)
          #  
          #  Sam Lown (2007-01-17) dev at samlown dot com
          define_method(column) do
            # This super should call the missing_method method in ActiveRecord.
            super()
          end
          
          alias_method("#{column}_before_translation", column)
          
          # overwrite accessor to read
          define_method("#{column}") do
            if translation and ! translation.send(column).blank?
              translation.send(column)
            else
              super()
            end
          end
          
          define_method("#{column}_before_type_cast") do 
            if (translation)
              translation.send("#{column}_before_type_cast")
            else
              super()
            end
          end
          
          define_method("#{column}=") do |value|
            # translation object must have already been set up for this to work!
            if (translation)
              translation.send("#{column}=",value)
            else
              super( value )
            end  
          end          

        end
      end # dynamic module

      # include the anonymous module so that the "super" method
      # will work correctly in the child!
      include mod
    end
    
  end

  # Methods that are specific to the current class
  # and only called when translate_columns is used
  module InstanceMethods
   
    # Provide the locale which is currently in use with the object or the current global locale.
    # If the default is in use, always return nil.
    def translation_locale
      locale = @translation_locale || I18n.locale.to_s
      locale == I18n.default_locale.to_s ? nil : locale
    end
    
    # Setting the locale will always enable translation.
    # If set to nil the global locale is used.
    def translation_locale=(locale)
      enable_translation
      # TODO some checks for available translations would be nice.
      # I18n.available_locales only available as standard with rails 2.3
      @translation_locale = locale.to_s.empty? ? nil : locale.to_s
    end
    
    # Do not allow translations!
    def disable_translation
      @disable_translation = true
    end
    def enable_translation
      @disable_translation = false 
    end     
   
    # Important check to see if the parent has a locale method.
    # If so, translations should be disabled if it is set to something!
    def has_locale_value?
      respond_to?(:locale) && !self.locale.to_s.empty?
    end

    # determine if the conditions are set for a translation to be used
    def translation_enabled?
      (!@disable_translation && translation_locale) and !has_locale_value? 
    end
    
    # Provide a translation object based on the parent and the translation_locale
    # current value.
    def translation
      if translation_enabled? 
        if !@translation || (@translation.locale != translation_locale)
          raise MissingParent, "Cannot create translations without a stored parent" if new_record?
          # try to find translation or build a new one
          @translation = translations.where(:locale => translation_locale).first || translations.build(:locale => translation_locale)
        end
        @translation
      else
        nil
      end
    end
    
    # As this is included in a mixin, a "super" call from inside the
    # child (inheriting) class will infact look here before looking to
    # ActiveRecord for the real 'save'. This method should therefore
    # be safely overridden if needed.      
    #
    # Assumes validation enabled in ActiveRecord and performs validation
    # before saving. This means the base records validation checks will always
    # be used.
    #
    def save_with_translation(*args)
      perform_validation = args.is_a?(Hash) ? args[:validate] : args
      if perform_validation && valid? || !perform_validation
        translation.save(*args) if (translation)
        disable_translation
        save_without_translation(*args)
        enable_translation
        true
      else
        false
      end
    end
    
    def save_with_translation!
      if valid?        
        translation.save! if (translation)
        disable_translation
        save_without_translation!
        enable_translation
      else
        raise ActiveRecord::RecordInvalid.new(self) 
      end
    rescue
      enable_translation
      raise
    end

    # Override the default mass assignment method so that the locale variable is always
    # given preference.
    def attributes_with_locale=(new_attributes, guard_protected_attributes = true)
      return if new_attributes.nil?
      attributes = new_attributes.dup
      attributes.stringify_keys!

      attributes = sanitize_for_mass_assignment(attributes) if guard_protected_attributes
      send(:locale=, attributes["locale"]) if attributes.has_key?("locale") and respond_to?(:locale=)

      send(:attributes_without_locale=, attributes, guard_protected_attributes)
    end

  end
end
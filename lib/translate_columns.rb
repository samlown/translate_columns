# 
# TranslateColumns
# 
# Copyright (c) 2007 Samuel Lown <me@samlown.com>
# 
module Translate
  module Columns
  
    def self.included(mod)
      mod.extend(ClassMethods)
    end
  
    DEFAULT_LOCALE_CLASS_NAME = 'Locale'
    
    # methods used in the class definition
    module ClassMethods
           
      # Read the provided list of symbols as column names and 
      # generate methods for each to access translated versions.
      # 
      # Possible options, after the columns, include:
      # 
      # * :locale_class - String of the name of the locale class used to determine
      # the current language in use. This overrides the 
      # Translate::Columns::DEFAULT_LOCALE_CLASS_NAME constant.
      # * :foreign_key - Name of the field in the parents translation table
      # of the locale. This defaults to the current locale class's name with 
      # +_id+ on the end, e.g. 'locale_id' for 'Locale'
      #
      def translate_columns( *options )
      
        locale_class = Translate::Columns::DEFAULT_LOCALE_CLASS_NAME
        locale_foreign_key = nil
        
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
            locale_class = opt[:locale_class] if opt[:locale_class]
            locale_foreign_key = opt[:foreign_key]
          end
        end
        
        # Perform some checks on the Locale class to ensure its for real
        locale_class = locale_class.constantize
        begin
          locale_class.global
        rescue
          raise "The locale class '#{locale_class}' does not provide a class method named 'global'."
        end
        if ! locale_class.method_defined? :id
          raise "No 'id' method provided by Locale."
        elsif ! locale_class.method_defined? 'master?'
          raise "Locale class does not provide 'master?' method."
        end
        
        # Create a semi-hidden method used to get hold of the locale class
        define_method '_locale_class' do
          locale_class
        end
        
        define_method '_locale_foreign_key' do
          if locale_foreign_key.blank?
            locale_class.to_s.underscore + '_id'
          else
            locale_foreign_key
          end
        end
        
        # The name of the association used by the translation table
        define_method '_locale_association' do
          locale_class.to_s.underscore
        end

        define_method 'columns_to_translate' do
          columns.collect{ |c| c.to_s }
        end
        
        # set the instance Methods first
        include Translate::Columns::InstanceMethods

               
        # Generate a module containing methods that override access 
        # to the ActiveRecord methods.
        # This dynamic module is then included in the parent such that
        # the super method will function correctly.
        mod = Module.new do | m |
          
          columns.each do | column |
          
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
            
            alias_method("#{column}_default", column)
            
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
                super
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
      
      # The locale variable is used by the translation function
      # to determine if a translation should be used.
      # If no locale has been set for this object, the Locale
      # class is checked if one has been set globally.
      # If a global is found, the object locale is set apropriatly.
      # Additionally, if the locale has the default value set to
      # true, it will not be used!
      def locale
        if @locale.nil? and ! _locale_class.global.nil?
          @locale = _locale_class.global
        end
        if @locale and ! @locale.master?
          return @locale
        end
        return nil
      end
      
      # Setting the locale will always enable translation.
      # If set to nil the global locale is used.
      def locale=(val)
        @disable_translation = false
        return if (! val)
        if (val.is_a?(Integer))
          @locale = _locale_class.find_by_id(val)
          raise "Invalid id provided to search for locale object." if @locale.nil?
        else
          @locale = val
        end
      end
      
      # Do not allow translations!
      def disable_translation
        @disable_translation = true
      end
      
      # If the current object has a locale set, return 
      # a translation object from the translations set
      def translation
        if ((! @disable_translation) and locale)
          if (! (@translation and (@translation.send(_locale_foreign_key) == locale.id)))
            # try to find entity in translations array
            @translation = nil
            self.translations.each do | t |
              if (t.send(_locale_foreign_key) == locale.id)
                @translation = t
                break;
              end
            end
            # @translation = self.translations.find(:first, :conditions=>['locale_id = ?', locale.id])
            if (! @translation)
              @translation = self.translations.build()
              @translation.send("#{_locale_association}=", locale)
            end
          end
          return @translation
        end
        return nil
      end
      
      # As this is included in a mixin, a "super" call from inside the
      # child (inheriting) class will infact look here before looking to
      # ActiveRecord for the real 'save'. This method should therefore
      # be safely overridden if needed.      
      def save
        save_and_disable_translation
        r = super
        enable_translation
        r
      end
      
      def save!
        save_and_disable_translation!
        r = super
        enable_translation
        r
      rescue
        enable_translation
        raise
      end
      
      protected

      def save_and_disable_translation
        translation.save if (translation)
        @disable_translation = true
      end
      
      def save_and_disable_translation!
        translation.save! if (translation)
        @disable_translation = true
      end
      
      def enable_translation
        @disable_translation = false 
      end     
             
    end
    
  end
end
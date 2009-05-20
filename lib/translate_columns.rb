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
        include Translate::Columns::InstanceMethods
               
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
     
      # Provide the locale which is currently in use with the object
      # or nil if we're using the default translation
      def locale
        I18n.locale.to_s == I18n.default_locale.to_s ? nil : (@locale ||= I18n.locale.to_s)
      end
      
      # Setting the locale will always enable translation.
      # If set to nil the global locale is used.
      def locale=(locale)
        @disable_translation = false
        return unless locale.to_s.empty?
        # TODO some checks for available translations would be nice.
        # I18n.available_locales only available as standard with rails 2.3
        @locale = locale.to_s
      end
      
      # Do not allow translations!
      def disable_translation
        @disable_translation = true
      end
      
      # If the current object has a locale set, return 
      # a translation object from the translations set
      def translation
        if !@disable_translation and locale
          if !@translation || (@translation.locale != locale)
            # try to find entity in translations array
            @translation = translations.find_by_locale(locale)
            @translation = self.translations.build(:locale => locale) unless @translation
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

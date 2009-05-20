= Translate Columns Plugin

Copyright (c) 2007 Samuel Lown <me (AT) samlown.com>

This Plugin is released under the MIT license, as Rails itself. Please see the 
attached LICENSE file for further details.

This document and plugin should be considered a work in progress until further
notice!

== Introduction

The aim of the Translate Columns plugin is to aid the normally difficult task 
of supporting multiple languages in the models. It provides a near transparent 
interface to the data contained in the models and their translations such that
your current controllers, views and models only need to be modified slightly 
to support multiple languages in a scalable fashion.

If you already have your rails app set up and functioning, using translate 
columns will not require any major refactoring of your code (unless you're 
really unlucky), and can be simply added. Indeed, the plugin was written to be 
added to an existing application.


== Architecture

Translate columns while simple, does require a specific architecture. The basic
idea is that each of your models has an associated model that defines the 
translations. An ASCII ERM that uses an example primary class called document 
follows:

  ____________                 _______________________
 |            | 1           * |                       |
 |  Document  |---------------|  DocumentTranslation  | 
 |____________|               |_______________________|
 

The data contained by these entities may be similar to the following:

 Document:

 |  Column    |   Type   |
 -------------------------
 | id         | integer  |
 | name       | string   |
 | title      | string   |
 | sub_title  | string   |
 | body       | text     |
 | created_on | datetime |
 | updated_on | datetime |
 
 DocumentTranslation:
 
 |  Column     |   Type   |
 --------------------------
 | id          | integer  |
 | locale_id   | integer  |  
 | document_id | integer  |
 | title       | string   |
 | sub_title   | string   |
 | body        | text     |

In Rails, thsee models would be defined as follows:

 class Document < ActiveRecord::Base
   has_many :translations, :class_name => 'DocumentTranslation'
 end

 class DocumentTranslation < ActiveRecord::Base
   belongs_to :document
   belongs_to :locale
 end

Each DocumentTranslation belongs to a Document and defines the locale of the
translation and only those fields that require a translation. If you really 
wanted to, a composite key could be used on the document_id and the locale_id,
as these should always uniquely identify the translation.

IMPORTANT: Default locale. In order for this setup to work, there must be a 
single, pre-defined locale for the default data, this is the data contained
in the 'Document' entity and will be used whenever we're operating in default
mode, or if there is no translation available. It is essential that this 
default locale *never* change during the lifetime of your application, 
otherwise you'll end up with a mess.

The Document's translations association uses the :class_name option to name the
correct class. Aside from saving on typing, this is an essential requirement 
of the translate_columns plugin. (At least until I get chance to add an option 
to allow for different names.)

The Locale class is left up to the developer to decide how to define and use
specifically, but suffice to say that it must exist as an ActiveRecord so that
associations will work correctly. Additionally, it must always be called 
'Locale' for the translation_column plugin to find it. More details 
are provided below, but in my implementations, I generally create my own Locale
class and add wrapper functions to control the Globalize plugin's Locale class.


== Installation

Assuming you've read the above and understand the basic requirements, the
plugin can now be installed and setup.

The latest version should always be available from:

https://ityzen.com/svn/translate_columns/trunk/vendor/plugins/translate_columns

Should you want to work on developing or testing the plugin, I'd suggest 
checking out the complete mini sample project:

https://ityzen.com/svn/translate_columns/trunk

To install plugin, use the standard rails plugin install method:

 ruby script/plugin install SVN
 
(Replace SVN with the long URL above.)

There are no more installation steps, and the plugin does not install any extra
files or customise the setup. To uninstall, simply remove the directory.


== Setup

Now for the hard part :-) Re-using the example above for documents, to use the
plugin modify the model so that it looks like the following:

 class Document < ActiveRecord::Base
   has_many :translations, :class_name => 'DocumentTranslation'
   translate_columns :title, :sub_title, :body
 end

I'm working on getting it so that you don't need to specify the columns
manually, but it is not yet ready.

As mentioned earlier, the plugin requires a Locale class and should look 
something like the following:

 class Locale < ActiveRecord::Base
   @@global_locale = nil

   def self.global
     @@global_locale
   end

   def self.global=( locale )
     if locale.is_a? Locale
       @@global_locale = locale
     elsif locale.is_a? String
       locale = Locale.find(:first, :conditions => ['short = ? OR code = ?', locale, locale])
       return false if (! locale)
       @@global_locale = locale
     else
       # empty
       @@global_locale = nil
     end
   end
   
   def master?
     self.master == true
   end
 end

In summary, your Locale class must provide one class and one instance methods;
access to the current global locale accessed through Locale.global and a check
to see if the current locale instance is the master/default locale. The 
Locale.global= method is provided as an example of how you could set it.

With the hard part done, you can start playing.


== Usage

The idea here is that you forget about the fact your models can be translated
and just use the app as normal. Indeed, if you don't set a global locale, you
won't even notice the plugin is there.

Here's a really basic example of what we can do on the console.

 Loading development environment.
 >> Locale.global = 'en'          # First try default language
 => "en"
 >> doc = Document.find(:first)
   -- output hidden --
 >> doc.title
 => "Sample Document"             # title in english
 >> Locale.global = 'es'          # set to other language
 => "es"
 >> doc = Document.find(:first)   # Reload to avoid caching problems!
   -- output hidden --
 >> doc.title
 => "Titulo español"              # Title now in spanish
 >> doc.title_default
 => "Sample Document"             # original field data
 >> doc.title = "Nuevo Título Español"
 => "Nuevo Título Español" 
 >> doc.save                      # set the title and save
 => true
 >> Locale.global = 'en'
 => "en"                          # return to english
 >> doc = Document.find(:first)
   -- output hidden --
 >> doc.title
 => "Sample Document"

As can be seen, just by setting the Locale we are able to edit the data
without having to worry about the details.


== How it works

The plugin overrides the default attribute accessor functions and automatically
uses the 'translations' association to find the request fields. It also 
provides a new method that extends the original method name to access 
the original values. The process used is called meta-programming and is one
of the powerful features of Ruby that allows Rails to do its magic.


== Todos / Bugs

* Caching - Using a basic rails setup, everything should work fine, however
  if you have a more complex caching setup strange things might happen.
  Please mail me if you have any problems!
  


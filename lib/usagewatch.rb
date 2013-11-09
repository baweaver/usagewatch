#License: (MIT), Copyright (C) 2013 Author Phil Chen, contributor Ruben Espinosa

require "usagewatch/version"

# I'll tweak with this one later. Better way to do it.
text =  "Unsupported OS! If you are using a Operating System that is not Linux, please try out the Gem usagewatch_ext by Ruben Espinosa" 

require "usagewatch/linux" if RUBY_PLATFORM.include? "linux"

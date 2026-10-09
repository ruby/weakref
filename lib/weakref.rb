# frozen_string_literal: true
require "delegate"

# Weak Reference class that allows a referenced object to be
# garbage-collected.
#
# A WeakRef may be used exactly like the object it references.
#
# Usage:
#
#   foo = Object.new            # create a new object instance
#   p foo.to_s                  # original's class
#   foo = WeakRef.new(foo)      # reassign foo with WeakRef instance
#   p foo.to_s                  # should be same class
#   GC.start                    # start the garbage collector
#   p foo.to_s                  # should raise exception (recycled)
#
# A WeakRef belongs to the Ractor that created it: the referenced object is
# usually not shareable, so it may not be reached from another Ractor.
# Consequently a WeakRef is neither shareable nor movable.

class WeakRef < Delegator
  # The version string
  VERSION = "0.1.4"

  ##
  # RefError is raised when a referenced object has been recycled by the
  # garbage collector

  class RefError < StandardError
  end

  # ObjectSpace::WeakMap is neither shareable nor thread safe, and its values
  # are the referenced objects, which are not shareable either. So each Ractor
  # gets its own map instead of one map shared by the whole process.
  if defined?(::Ractor) && ::Ractor.respond_to?(:store_if_absent)
    def self.__map__ # :nodoc:
      ::Ractor.store_if_absent(:__weakref_map__) { ::ObjectSpace::WeakMap.new }
    end
  elsif defined?(::Ractor)
    # Ractor.store_if_absent is Ruby 3.4 and later. Two threads of the same
    # Ractor can race here and each build a map, but that only leaves one empty
    # map behind: every WeakRef keeps the map it registered itself in.
    def self.__map__ # :nodoc:
      current = ::Ractor.current
      current[:__weakref_map__] ||= ::ObjectSpace::WeakMap.new
    end
  else
    @__map = ::ObjectSpace::WeakMap.new

    def self.__map__ # :nodoc:
      @__map
    end
  end

  ##
  # Creates a weak reference to +orig+

  def initialize(orig)
    case orig
    when true, false, nil
      @map = nil
      @delegate_sd_obj = orig
    else
      # Holding the map in an instance variable keeps lookups to a single ivar
      # read, and makes the WeakRef itself non-shareable and non-movable, which
      # is what we want: its entry lives in this Ractor's map only.
      # Delegator does not inherit from Object, so a bare constant here would go
      # through Delegator.const_missing on every call.
      @map = ::WeakRef.__map__
      @map[self] = orig
    end
    super
  end

  def __getobj__(&_block) # :nodoc:
    @map && @map[self] or defined?(@delegate_sd_obj) ? @delegate_sd_obj :
      Kernel::raise(RefError, "Invalid Reference - probably recycled", Kernel::caller(2))
  end

  def __setobj__(obj) # :nodoc:
  end

  ##
  # Returns true if the referenced object is still alive.

  def weakref_alive?
    (@map ? @map.key?(self) : false) or defined?(@delegate_sd_obj)
  end
end

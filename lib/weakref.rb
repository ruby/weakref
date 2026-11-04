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

class WeakRef < Delegator
  # The version string
  VERSION = "0.1.4"

  ##
  # RefError is raised when a referenced object has been recycled by the
  # garbage collector

  class RefError < StandardError
  end

  ##
  # Creates a weak reference to +orig+

  def initialize(orig)
    case orig
    when true, false, nil, Symbol, Integer, Float, Complex, Rational
      @weak = false
      @store = orig
    else
      @weak = true
      @store = ::ObjectSpace::WeakMap.new
      @store[self] = orig
    end
  end

  def __getobj__(&_block) # :nodoc:
    return @store unless @weak
    @store[self] or ::Kernel::raise(RefError, "Invalid Reference - probably recycled", ::Kernel::caller(2))
  end

  def __setobj__(obj) # :nodoc:
  end

  ##
  # Returns true if the referenced object is still alive.

  def weakref_alive?
    !@weak || @store.key?(self)
  end
end

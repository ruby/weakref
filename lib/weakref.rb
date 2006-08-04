require "delegate"

# WeakRef is a class to represent a reference to an object that is not seen by
# the tracing phase of the garbage collector.  This allows the referenced
# object to be garbage collected as if nothing is referring to it. Because
# WeakRef delegates method calls to the referenced object, it may be used in
# place of that object, i.e. it is of the same duck type.
#
# Usage:
#
#   foo = Object.new
#   foo = Object.new
#   p foo.to_s			# original's class
#   foo = WeakRef.new(foo)
#   p foo.to_s			# should be same class
#   ObjectSpace.garbage_collect
#   p foo.to_s			# should raise exception (recycled)
class WeakRef<Delegator

  # RefError is raised if an object cannot be referenced by a WeakRef.
  class RefError<StandardError
  end

  @@id_map =  {}                # obj -> [ref,...]
  @@id_rev_map =  {}            # ref -> obj
  @@final = lambda {|id|
    printf "final: %p\n", id
    __old_status = Thread.critical
    Thread.critical = true
    begin
      rids = @@id_map[id]
      if rids
	for rid in rids
	  @@id_rev_map.delete(rid)
	end
	@@id_map.delete(id)
      end
      rid = @@id_rev_map[id]
      if rid
	@@id_rev_map.delete(id)
	@@id_map[rid].delete(id)
	@@id_map.delete(rid) if @@id_map[rid].empty?
      end
    ensure
      Thread.critical = __old_status
    end
  }

  # Create a new WeakRef from +orig+.
  def initialize(orig)
    @__id = orig.object_id
    printf "orig: %p\n", @__id
    ObjectSpace.define_finalizer orig, @@final
    ObjectSpace.define_finalizer self, @@final
    __old_status = Thread.critical
    begin
      Thread.critical = true
      @@id_map[@__id] = [] unless @@id_map[@__id]
    ensure
      Thread.critical = __old_status
    end
    @@id_map[@__id].push self.object_id
    @@id_rev_map[self.object_id] = @__id
    super
  end

  # Return the object this WeakRef references. Raises RefError if the object
  # has been garbage collected.  The object returned is the object to which
  # method calls are delegated (see Delegator).
  def __getobj__
    unless @@id_rev_map[self.object_id] == @__id
      Kernel::raise RefError, "Illegal Reference - probably recycled", Kernel::caller(2)
    end
    begin
      ObjectSpace._id2ref(@__id)
    rescue RangeError
      Kernel::raise RefError, "Illegal Reference - probably recycled", Kernel::caller(2)
    end
  end

  def __setobj__(obj)
  end

  # Returns true if the referenced object still exists, and false if it has
  # been garbage collected.
  def weakref_alive?
    @@id_rev_map[self.object_id] == @__id
  end
end

if __FILE__ == $0
#  require 'thread'
  foo = Object.new
  p foo.to_s			# original's class
  foo = WeakRef.new(foo)
  p foo.to_s			# should be same class
  ObjectSpace.garbage_collect
  ObjectSpace.garbage_collect
  p foo.to_s			# should raise exception (recycled)
end

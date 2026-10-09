# frozen_string_literal: true
require 'test/unit'
require 'weakref'

class TestWeakRef < Test::Unit::TestCase
  def make_weakref(level = 10)
    if level > 0
      make_weakref(level - 1)
    else
      WeakRef.new(Object.new)
    end
  end

  def test_ref
    obj = Object.new
    weak = WeakRef.new(obj)
    assert_equal(obj.to_s, weak.to_s)
    assert_predicate(weak, :weakref_alive?)
  end

  def test_recycled
    weaks = []
    weak = nil
    100.times do
      weaks << make_weakref
      ObjectSpace.garbage_collect
      ObjectSpace.garbage_collect
      break if weak = weaks.find {|w| !w.weakref_alive?}
    end
    assert_raise(WeakRef::RefError) {weak.to_s}
    assert_not_predicate(weak, :weakref_alive?)
  end

  def test_not_reference_different_object
    bug7304 = '[ruby-core:49044]'
    weakrefs = []
    3.times do
      obj = Object.new
      def obj.foo; end
      weakrefs << WeakRef.new(obj)
      ObjectSpace.garbage_collect
    end
    assert_nothing_raised(NoMethodError, bug7304) {
      weakrefs.each do |weak|
        begin
          weak.foo
        rescue WeakRef::RefError
        end
      end
    }
  end

  def test_weakref_finalize
    bug7304 = '[ruby-core:49044]'
    assert_normal_exit %q{
      require 'weakref'
      obj = Object.new
      3.times do
        WeakRef.new(obj)
        ObjectSpace.garbage_collect
      end
    }, bug7304
  end

  def test_repeated_object_memory_leak
    bug10537 = '[ruby-core:66428]'
    assert_no_memory_leak(%w(-rweakref), '', <<-'end;', bug10537, timeout: 60)
      a = Object.new
      150_000.times { WeakRef.new(a) }
    end;
  end

  if defined?(Ractor)
    def test_weakref_in_ractor
      bug22105 = '[ruby-core:125705]'
      assert_separately(%w(-rweakref), <<-'end;', ignore_stderr: true)
        Warning[:experimental] = false
        ractor = Ractor.new do
          str = "referenced"
          ref = WeakRef.new(str)
          [ref.__getobj__, ref.weakref_alive?]
        end
        # Ractor#value is 4.0 and later, Ractor#take before that.
        obj, alive = ractor.respond_to?(:value) ? ractor.value : ractor.take
        assert_equal("referenced", obj)
        assert_equal(true, alive)
      end;
    end

    def test_map_is_per_ractor
      assert_separately(%w(-rweakref), <<-'end;', ignore_stderr: true)
        Warning[:experimental] = false
        ractor = Ractor.new { WeakRef.__map__.object_id }
        other = ractor.respond_to?(:value) ? ractor.value : ractor.take
        assert_not_equal(WeakRef.__map__.object_id, other)
      end;
    end

    def test_weakref_is_not_shareable
      # The referenced object belongs to the Ractor that created the WeakRef,
      # so the WeakRef must not escape it.
      assert_separately(%w(-rweakref), <<-'end;', ignore_stderr: true)
        Warning[:experimental] = false
        ref = WeakRef.new(Object.new)
        assert_raise(Ractor::Error) { Ractor.make_shareable(ref) }
      end;
    end
  end
end

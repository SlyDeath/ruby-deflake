# frozen_string_literal: true

module Deflake
  module Leaks
    # ActiveSupport::CurrentAttributes left set, or with a default changed in place
    class Current
      # Attributes left set, and a print of every default that is not a proc
      State = Struct.new(:attributes, :defaults)

      def snapshot
        return unless defined?(::ActiveSupport) && Leaks.loaded?(::ActiveSupport, :CurrentAttributes)

        classes = ::ActiveSupport::CurrentAttributes.descendants.select(&:name)
        attributes = classes.filter_map do |klass|
          instance = existing_instance(klass)
          [klass.name, changed_attributes(klass, instance)] if instance
        end
        State.new(attributes.to_h, classes.to_h { |klass| [klass.name, defaults(klass)] })
      end

      def diff(before, after)
        set(before.attributes, after.attributes) + changed_defaults(before.defaults, after.defaults)
      end

      private

      def set(before, after)
        after.flat_map do |klass, attributes|
          attributes.filter_map do |name, value|
            next if NilClass === value # rubocop:disable Style/CaseEquality
            next if before.fetch(klass, {}).key?(name) && same?(before[klass][name], value)

            "#{klass}.#{name} is still set"
          end
        end
      end

      # ActiveSupport copies a default only one level deep, so a test that changes a list inside
      # one changes the default of every later test
      def changed_defaults(before, after)
        after.flat_map do |klass, defaults|
          defaults.filter_map do |name, print|
            was = before.fetch(klass, {})[name]
            "#{klass}.#{name}'s default was changed in place" if was && print && was != print
          end
        end
      end

      # Asking the class for its attributes would create the instance and run the
      # proc defaults before the test, which may travel in time first. A class
      # without an instance has nothing set
      def existing_instance(klass)
        return unless klass.respond_to?(:current_instances, true)

        key = klass.respond_to?(:current_instances_key, true) ? klass.send(:current_instances_key) : klass.name
        klass.send(:current_instances)[key]
      end

      # Attributes that differ from their defaults. A default given as a proc gives a new value
      # after every reset, so such attributes are not compared. A value may be any object, even a
      # mock without Kernel's methods
      def changed_attributes(klass, instance)
        defaults = klass.respond_to?(:defaults) ? klass.defaults : {}
        instance.attributes.reject do |name, value|
          default = defaults[name]
          Proc === default || NilClass === value || same?(value, default) # rubocop:disable Style/CaseEquality
        end
      end

      def defaults(klass)
        return {} unless klass.respond_to?(:defaults)

        klass.defaults.reject { |_, default| Proc === default }.transform_values do |default| # rubocop:disable Style/CaseEquality
          Marshal.dump(default).hash
        rescue StandardError
          nil
        end
      end

      def same?(one, other)
        one.__id__ == other.__id__ || one == other
      rescue StandardError
        false
      end
    end
  end
end

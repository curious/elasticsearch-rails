module Elasticsearch
  module Model
    module Response

      # Encapsulates the collection of records returned from the database
      #
      # Implements Enumerable and forwards its methods to the {#records} object,
      # which is provided by an {Elasticsearch::Model::Adapter::Adapter} implementation.
      #
      class Records
        include Enumerable

        delegate :each, :empty?, :size, :slice, :[], :to_a, :to_ary, to: :records

        include Base

        # @see Base#initialize
        #
        def initialize(klass, response, options={})
          super

          # Include module provided by the adapter in the singleton class ("metaclass")
          #
          adapter = Adapter.from_class(klass)
          metaclass = class << self; self; end
          metaclass.__send__ :include, adapter.records_mixin
          @deferred_calls = {}

          self
        end

        # Returns the hit IDs
        #
        def ids
          response.response['hits']['hits'].map { |hit| hit['_id'] }
        end

        # Returns the {Results} collection
        #
        def results
          response.results
        end

        # Yields [record, hit] pairs to the block
        #
        def each_with_hit(&block)
          records.to_a.zip(results).each(&block)
        end

        # Yields [record, hit] pairs and returns the result
        #
        def map_with_hit(&block)
          records.to_a.zip(results).map(&block)
        end

        # Delegate missing methods to `@records`, or defer them if indicated.
        #
        def method_missing(method_name, *arguments)
          if records.respond_to?(method_name)
            # If this method is explicitly listed as deferred, then don't send it to records, just store it for later.
            # QQQ: should this be true for all of the method_missing records passthrough methods, rather than whitelisted?
            if deferred_methods.include?(method_name)
              @deferred_calls[method_name] = arguments
              self
            else
              records.__send__(method_name, *arguments)
            end
          else
            super
          end
        end

        # Respond to methods from `@records`
        #
        def respond_to?(method_name, include_private = false)
          # Lead with super, otherwise the 'records' method can't call any methods on its own instance (infinite recursion)
          # Note that it still can't call a method implemented through method missing...
          super || records.respond_to?(method_name)
        end

        private

        # Apply any calls that were deferred rather than applied immediately
        def apply_deferred_calls(criteria)
          @deferred_calls.each { |method_name, arguments| criteria = criteria.public_send(method_name, *arguments) }
          criteria
        end

        # Methods that should not be passed to records at call time, but instead should be
        # stored and applied when converting to a relation.
        # No methods are included by default.
        def deferred_methods
          []
        end
      end
    end
  end
end

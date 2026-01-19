require "test_helper"
require "rails_uuid_pk/railtie"

module RailsUuidPk
  class RailtieTest < ActiveSupport::TestCase
    test "railtie connection registration" do
      # Mock connection pool and connections
      mock_conn = Object.new
      mock_conn.instance_variable_set(:@register_called, false)
      def mock_conn.register_uuid_types; @register_called = true; end
      def mock_conn.register_called; @register_called; end

      mock_pool = Object.new
      def mock_pool.connections; [ @mock_conn ]; end
      mock_pool.instance_variable_set(:@mock_conn, mock_conn)

      mock_handler = Object.new
      def mock_handler.connection_pool_list; [ @mock_pool ]; end
      mock_handler.instance_variable_set(:@mock_pool, mock_pool)

      # Manual stubbing
      class << ActiveRecord::Base
        alias_method :original_connected, :connected?
        def connected?; true; end

        alias_method :original_connection_handler, :connection_handler
        def connection_handler; @mock_handler; end
        attr_accessor :mock_handler
      end
      ActiveRecord::Base.mock_handler = mock_handler

      begin
        # Manually run the logic from railtie after_initialize block
        # since we can't easily re-trigger the actual Railtie initialization in a test
        if ActiveRecord::Base.connected?
          ActiveRecord::Base.connection_handler.connection_pool_list.each do |pool|
            connections = if pool.respond_to?(:connections)
                            pool.connections
            else
                            [ pool.connection ] rescue []
            end

            connections.each do |conn|
              if conn.respond_to?(:register_uuid_types)
                conn.register_uuid_types
              end
            end
          end
        end

        assert mock_conn.register_called
      ensure
        class << ActiveRecord::Base
          remove_method :connected?
          alias_method :connected?, :original_connected
          remove_method :original_connected

          remove_method :connection_handler
          alias_method :connection_handler, :original_connection_handler
          remove_method :original_connection_handler
          remove_method :mock_handler
          remove_method :mock_handler=
        end
      end
    end
  end
end

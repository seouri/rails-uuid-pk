require "test_helper"
require "generators/rails_uuid_pk/add_opt_outs_generator"

module RailsUuidPk
  module Generators
    class AddOptOutsGeneratorTest < Minitest::Test
      def setup
        @generator = AddOptOutsGenerator.new
        @temp_dir = Dir.mktmpdir
        @generator.instance_variable_set(:@destination_root, @temp_dir)

        @model_content = <<~RUBY
          class TestModel < ApplicationRecord
          end
        RUBY

        @model_with_opt_out_content = <<~RUBY
          class TestModelWithOptOut < ApplicationRecord
            use_integer_primary_key
          end
        RUBY
      end

      def teardown
        FileUtils.remove_entry @temp_dir

        # Cleanup constants if defined
        Object.send(:remove_const, :CoverageUser) if Object.const_defined?(:CoverageUser)
        Object.send(:remove_const, :CoveragePost) if Object.const_defined?(:CoveragePost)
        Object.send(:remove_const, :CoveragePlain) if Object.const_defined?(:CoveragePlain)
      end

      def test_extract_class_name_from_file
        file_path = File.join(@temp_dir, "test_model.rb")
        File.write(file_path, @model_content)
        class_name = @generator.send(:extract_class_name_from_file, file_path)
        assert_equal "TestModel", class_name
      end

      def test_extract_class_name_with_namespace
        namespaced_content = <<~RUBY
          module Api
            class V1::User < ApplicationRecord
            end
          end
        RUBY
        file_path = File.join(@temp_dir, "test_model.rb")
        File.write(file_path, namespaced_content)
        class_name = @generator.send(:extract_class_name_from_file, file_path)
        assert_equal "V1::User", class_name
      end

      def test_model_file_has_opt_out
        file_path_without = File.join(@temp_dir, "without.rb")
        File.write(file_path_without, @model_content)

        file_path_with = File.join(@temp_dir, "with.rb")
        File.write(file_path_with, @model_with_opt_out_content)

        refute @generator.send(:model_file_has_opt_out?, file_path_without)
        assert @generator.send(:model_file_has_opt_out?, file_path_with)
      end

      def test_check_primary_key_type_integer
        column = Object.new
        def column.name; "id"; end
        def column.type; :integer; end
        connection = Object.new
        connection.instance_variable_set(:@column, column)
        def connection.columns(table); [ @column ]; end

        result = @generator.send(:check_primary_key_type, "test_table", connection)
        assert_equal :integer, result
      end

      def test_check_primary_key_type_uuid
        column = Object.new
        def column.name; "id"; end
        def column.type; :uuid; end
        connection = Object.new
        connection.instance_variable_set(:@column, column)
        def connection.columns(table); [ @column ]; end

        result = @generator.send(:check_primary_key_type, "test_table", connection)
        assert_equal :uuid, result
      end

      def test_check_primary_key_type_string_uuid
        column = Object.new
        def column.name; "id"; end
        def column.type; :string; end
        def column.limit; 36; end
        connection = Object.new
        connection.instance_variable_set(:@column, column)
        def connection.columns(table); [ @column ]; end

        result = @generator.send(:check_primary_key_type, "test_table", connection)
        assert_equal :uuid, result
      end

      def test_add_opt_out_to_model
        file_path = File.join(@temp_dir, "test_model.rb")
        File.write(file_path, @model_content)

        result = @generator.send(:add_opt_out_to_model, file_path, "TestModel")
        assert result

        content = File.read(file_path)
        assert_match(/use_integer_primary_key/, content)
      end

      def test_add_opt_out_to_model_with_existing_methods
        content_with_methods = <<~RUBY
          class TestModel < ApplicationRecord
            validates :name, presence: true

            def some_method
            end
          end
        RUBY

        file_path = File.join(@temp_dir, "test_model.rb")
        File.write(file_path, content_with_methods)

        result = @generator.send(:add_opt_out_to_model, file_path, "TestModel")
        assert result

        content = File.read(file_path)
        lines = content.lines

        # Find the use_integer_primary_key line
        opt_out_index = lines.index { |line| line.include?("use_integer_primary_key") }
        # Find the validates line
        validates_index = lines.index { |line| line.include?("validates") }

        # Opt-out should be added before validates
        assert opt_out_index < validates_index
      end

      def test_find_model_files
        # Create app/models directory structure
        models_dir = File.join(@temp_dir, "app", "models")
        FileUtils.mkdir_p(models_dir)

        user_file = File.join(models_dir, "user.rb")
        post_file = File.join(models_dir, "post.rb")
        File.write(user_file, @model_content)
        File.write(post_file, @model_content)

        # Verify files exist
        assert File.exist?(user_file)
        assert File.exist?(post_file)

        # Mock destination_root method using instance_eval
        @generator.instance_eval do
          def destination_root
            @destination_root || "/tmp"
          end
        end
        @generator.instance_variable_set(:@destination_root, @temp_dir)

        # Test the actual generator method
        files = @generator.send(:find_model_files)
        assert_includes files, user_file
        assert_includes files, post_file
      end

      def test_add_opt_out_to_model_error_handling
        # Create a file that will cause an error when writing
        models_dir = File.join(@temp_dir, "app", "models")
        FileUtils.mkdir_p(models_dir)
        model_file = File.join(models_dir, "error_model.rb")
        File.write(model_file, @model_content)

        # Make file read-only to cause write error
        File.chmod(0444, model_file)

        result = @generator.send(:add_opt_out_to_model, model_file, "ErrorModel")
        refute result

        # Restore permissions for cleanup
        File.chmod(0644, model_file)
      end

      def test_add_opt_out_to_model_with_malformed_class
        malformed_content = <<~RUBY
          # Missing class definition
          def some_method
          end
        RUBY

        file_path = File.join(@temp_dir, "malformed.rb")
        File.write(file_path, malformed_content)

        result = @generator.send(:add_opt_out_to_model, file_path, "MalformedModel")
        refute result
      end

      def test_check_primary_key_type_unknown_column
        connection = Object.new
        def connection.columns(table)
          [] # No columns
        end

        result = @generator.send(:check_primary_key_type, "empty_table", connection)
        assert_equal :unknown, result
      end

      def test_check_primary_key_type_unknown_type
        column = Object.new
        def column.name; "id"; end
        def column.type; :unknown_type; end
        connection = Object.new
        connection.instance_variable_set(:@column, column)
        def connection.columns(table); [ @column ]; end

        result = @generator.send(:check_primary_key_type, "test_table", connection)
        assert_equal :unknown, result
      end

      def test_analyze_models_with_various_model_files
        FileUtils.mkdir_p(File.join(@temp_dir, "app/models"))

        # Mock destination_root method
        @generator.instance_eval do
          def destination_root
            @destination_root
          end
          def destination_root=(val)
            @destination_root = val
          end
        end
        @generator.destination_root = @temp_dir

        # Create an integer PK model
        File.write(File.join(@temp_dir, "app/models/coverage_user.rb"), <<~RUBY)
          class CoverageUser < ActiveRecord::Base
          end
        RUBY

        # Create a UUID PK model
        File.write(File.join(@temp_dir, "app/models/coverage_post.rb"), <<~RUBY)
          class CoveragePost < ActiveRecord::Base
          end
        RUBY

        # Create a non-ActiveRecord model
        File.write(File.join(@temp_dir, "app/models/coverage_plain.rb"), <<~RUBY)
          class CoveragePlain
          end
        RUBY

        # Mock connection
        mock_conn = Object.new
        def mock_conn.table_exists?(name); true; end
        def mock_conn.columns(table_name)
          col = Object.new
          def col.name; "id"; end
          if table_name == "coverage_users"
            def col.type; :integer; end
          else
            def col.type; :uuid; end
          end
          [ col ]
        end

        # Define test classes
        Object.const_set(:CoverageUser, Class.new(ActiveRecord::Base) { self.table_name = "coverage_users" })
        Object.const_set(:CoveragePost, Class.new(ActiveRecord::Base) { self.table_name = "coverage_posts" })
        Object.const_set(:CoveragePlain, Class.new)

        # Manual stubbing of ActiveRecord::Base.connection
        class << ActiveRecord::Base
          alias_method :original_connection, :connection
          def connection; @mock_connection; end
          attr_accessor :mock_connection
        end
        ActiveRecord::Base.mock_connection = mock_conn

        begin
          results = @generator.send(:analyze_models)

          assert_equal 2, results.size
          user_result = results.find { |r| r[:model_class] == CoverageUser }
          post_result = results.find { |r| r[:model_class] == CoveragePost }

          assert user_result[:needs_opt_out]
          refute post_result[:needs_opt_out]
        ensure
          class << ActiveRecord::Base
            remove_method :connection
            alias_method :connection, :original_connection
            remove_method :original_connection
            remove_method :mock_connection
            remove_method :mock_connection=
          end
        end
      end

      def test_analyze_and_modify_models_integration
        FileUtils.mkdir_p(File.join(@temp_dir, "app/models"))

        # Mock destination_root method
        @generator.instance_eval do
          def destination_root
            @destination_root
          end
          def destination_root=(val)
            @destination_root = val
          end
        end
        @generator.destination_root = @temp_dir

        # Setup integer PK model
        File.write(File.join(@temp_dir, "app/models/coverage_user.rb"), <<~RUBY)
          class CoverageUser < ActiveRecord::Base
          end
        RUBY

        mock_conn = Object.new
        def mock_conn.table_exists?(name); true; end
        def mock_conn.columns(table_name)
          col = Object.new
          def col.name; "id"; end
          def col.type; :integer; end
          [ col ]
        end

        Object.const_set(:CoverageUser, Class.new(ActiveRecord::Base) { self.table_name = "coverage_users" })

        # Manual stubbing
        class << ActiveRecord::Base
          alias_method :original_connection2, :connection
          def connection; @mock_connection2; end
          attr_accessor :mock_connection2
        end
        ActiveRecord::Base.mock_connection2 = mock_conn

        begin
          # Run generator
          @generator.analyze_and_modify_models
        ensure
          class << ActiveRecord::Base
            remove_method :connection
            alias_method :connection, :original_connection2
            remove_method :original_connection2
            remove_method :mock_connection2
            remove_method :mock_connection2=
          end
        end

        # Verify file was modified
        content = File.read(File.join(@temp_dir, "app/models/coverage_user.rb"))
        assert_match(/use_integer_primary_key/, content)
      end
    end
  end
end

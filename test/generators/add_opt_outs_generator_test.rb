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
    end
  end
end

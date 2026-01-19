require "rails/generators/base"

module RailsUuidPk
  # Rails generators for the rails-uuid-pk gem.
  #
  # This module contains Rails generator classes that help with migration
  # and setup tasks for applications using UUID primary keys.
  #
  # @see RailsUuidPk::Generators::AddOptOutsGenerator
  module Generators
    # Rails generator that scans all ActiveRecord models in a Rails application
    # and adds `use_integer_primary_key` to models that have integer primary keys
    # in the database schema.
    #
    # This generator helps migrate existing Rails applications that use integer
    # primary keys to work correctly with the rails-uuid-pk gem, which assumes
    # UUID primary keys by default.
    #
    # @example Run the generator
    #   rails generate rails_uuid_pk:add_opt_outs
    #
    # @example Run with dry-run to see what would be changed
    #   rails generate rails_uuid_pk:add_opt_outs --dry-run
    #
    # @see RailsUuidPk::HasUuidv7PrimaryKey
    # @see https://github.com/seouri/rails-uuid-pk
    class AddOptOutsGenerator < Rails::Generators::Base
      include Thor::Actions

      desc "Scans all ActiveRecord models and adds use_integer_primary_key to models with integer primary keys"

      class_option :dry_run, type: :boolean, default: false, desc: "Show what would be changed without modifying files"
      class_option :verbose, type: :boolean, default: true, desc: "Provide detailed output for each model processed"



      # Analyzes all ActiveRecord models and modifies those with integer primary keys.
      #
      # This is the main generator method that orchestrates the entire process:
      # 1. Finds all model files in the application
      # 2. Analyzes each model for integer primary keys
      # 3. Modifies model files to add opt-out calls
      # 4. Reports results to the user
      #
      # @return [void]
      def analyze_and_modify_models
        say_status :info, "Analyzing ActiveRecord models for integer primary keys...", :blue

        results = analyze_models

        modified_count = 0
        analyzed_count = results.size

        results.each do |result|
          if options[:verbose]
            status = case
            when result[:modified] then :modified
            when result[:needs_opt_out] && !result[:already_has_opt_out] then :pending
            else :skipped
            end
            say_status status, "#{result[:model_class].name} (table: #{result[:table_name]}, pk: #{result[:primary_key_type]})", :green
          end

          modified_count += 1 if result[:modified]
        end

        say_status :success, "Analyzed #{analyzed_count} models, modified #{modified_count} files", :green
      end

      private

      def analyze_models
        model_files = find_model_files
        connection = ActiveRecord::Base.connection

        model_files.map do |file_path|
          class_name = extract_class_name_from_file(file_path)
          next unless class_name

          model_class = class_name.constantize
          next unless model_class < ActiveRecord::Base

          table_name = model_class.table_name
          next unless connection.table_exists?(table_name)

          primary_key_type = check_primary_key_type(table_name, connection)
          already_has_opt_out = model_file_has_opt_out?(file_path)

          needs_opt_out = primary_key_type == :integer && !already_has_opt_out

          modified = false
          if needs_opt_out && !options[:dry_run]
            modified = add_opt_out_to_model(file_path, class_name)
          end

          {
            model_class: model_class,
            table_name: table_name,
            primary_key_type: primary_key_type,
            needs_opt_out: needs_opt_out,
            already_has_opt_out: already_has_opt_out,
            file_path: file_path,
            modified: modified
          }
        end.compact
      end

      def find_model_files
        Dir.glob(File.join(destination_root, "app/models/**/*.rb"))
      end

      def extract_class_name_from_file(file_path)
        content = File.read(file_path)
        # Simple regex to find class definition - this is a basic implementation
        # In a real scenario, you'd want to use a Ruby parser for accuracy
        match = content.match(/class\s+([A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)*)/)
        match[1] if match
      end

      def check_primary_key_type(table_name, connection)
        columns = connection.columns(table_name)
        pk_column = columns.find { |col| col.name == "id" }
        return :unknown unless pk_column

        # Map database types to our categories
        case pk_column.type
        when :integer then :integer
        when :string then pk_column.limit == 36 ? :uuid : :string
        when :uuid then :uuid
        else :unknown
        end
      end

      def model_file_has_opt_out?(file_path)
        content = File.read(file_path)
        content.include?("use_integer_primary_key")
      end

      def add_opt_out_to_model(file_path, class_name)
        content = File.read(file_path)

        # Find the class definition line
        class_match = content.match(/^(\s*)class\s+#{Regexp.escape(class_name)}/)
        return false unless class_match

        indent = class_match[1]

        # Find where to insert - after the class definition and any initial comments/constants
        lines = content.lines
        insert_index = nil

        lines.each_with_index do |line, index|
          if line.match?(/^#{Regexp.escape(indent)}class\s+#{Regexp.escape(class_name)}/)
            # Start looking for insertion point after this line
            (index + 1..lines.size - 1).each do |i|
              current_line = lines[i]
              next if current_line.strip.empty? || current_line.match?(/^#{Regexp.escape(indent)}\s*#/)

              # Insert before the first indented content or end of class
              if current_line.match?(/^#{Regexp.escape(indent)}\s+\S/) || current_line.match?(/^#{Regexp.escape(indent)}end$/) || i == lines.size - 1
                insert_index = i
                break
              end
            end
            break
          end
        end

        return false unless insert_index

        # Insert the opt-out method call
        opt_out_line = "\n#{indent}  use_integer_primary_key\n"
        new_content = lines.insert(insert_index, opt_out_line).join

        File.write(file_path, new_content)
        true
      rescue => e
        say_status :error, "Failed to modify #{file_path}: #{e.message}", :red
        false
      end
    end
  end
end

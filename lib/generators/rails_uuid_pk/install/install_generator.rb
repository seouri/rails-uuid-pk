module RailsUuidPk
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs rails-uuid-pk: sets uuid primary key + includes UUIDv7 concern"

      def add_concern_file
        copy_file "has_uuidv7_primary_key.rb",
                  "app/models/concerns/has_uuidv7_primary_key.rb"
      end

      def show_next_steps
        say "\nrails-uuid-pk was successfully installed!", :green

        say "\n✅ Action Text & Active Storage compatibility", :green
        say "─────────────────────────────────────────────────────────────"
        say "Migration helpers now automatically handle foreign key types!"
        say "When you run:"
        say "  rails action_text:install"
        say "  rails active_storage:install"
        say ""
        say "The generated migrations will automatically use the correct UUID types"
        say "for foreign keys. No manual editing required!"
        say "─────────────────────────────────────────────────────────────\n"

        say "\nRecommended next steps:", :yellow
        say "  1. Add to ApplicationRecord (if you prefer explicit include):"
        say "     class ApplicationRecord < ActiveRecord::Base"
        say "       primary_abstract_class"
        say "       include HasUuidv7PrimaryKey"
        say "     end\n"

        say "  2. Or keep relying on Railtie automatic include (recommended for most cases)\n"

        say "  3. Now you can run:", :cyan
        say "     rails g model User name:string email:string\n"
        say "     → will create table with uuid primary key + automatic uuidv7\n"
      end
    end
  end
end

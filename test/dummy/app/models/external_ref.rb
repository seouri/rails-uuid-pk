class ExternalRef < ApplicationRecord
  use_integer_primary_key
  belongs_to :user
end

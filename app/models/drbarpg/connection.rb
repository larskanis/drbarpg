module Drbarpg
  class Connection < ActiveRecord::Base
    has_many :messages
  end
end

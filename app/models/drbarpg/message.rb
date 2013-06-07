module Drbarpg
  class Message < ActiveRecord::Base
    belongs_to :connection
  end
end

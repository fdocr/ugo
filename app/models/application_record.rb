class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def errors_as_sentence
    self.errors.full_messages.join(", ")
  end
end

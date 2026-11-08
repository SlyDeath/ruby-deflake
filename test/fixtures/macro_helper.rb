# frozen_string_literal: true

# A macro that defines a test, as a project's test_helper may
module Macros
  def requires_login(path)
    define_method("test_#{path.delete("/")}_requires_login") { flunk "#{path} let a guest in" }
  end
end

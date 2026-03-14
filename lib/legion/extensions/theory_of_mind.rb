# frozen_string_literal: true

require 'legion/extensions/theory_of_mind/version'
require 'legion/extensions/theory_of_mind/helpers/constants'
require 'legion/extensions/theory_of_mind/helpers/agent_model'
require 'legion/extensions/theory_of_mind/helpers/mental_state_tracker'
require 'legion/extensions/theory_of_mind/runners/theory_of_mind'
require 'legion/extensions/theory_of_mind/client'

module Legion
  module Extensions
    module TheoryOfMind
      extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core)
    end
  end
end

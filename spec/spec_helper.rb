# frozen_string_literal: true

require 'rspec'

module Legion
  module Extensions
    module Helpers; end
    module Core; end
  end

  module Logging
    def self.debug(*); end

    def self.info(*); end

    def self.warn(*); end

    def self.error(*); end
  end
end

require 'legion/extensions/theory_of_mind/version'
require 'legion/extensions/theory_of_mind/helpers/constants'
require 'legion/extensions/theory_of_mind/helpers/agent_model'
require 'legion/extensions/theory_of_mind/helpers/mental_state_tracker'
require 'legion/extensions/theory_of_mind/runners/theory_of_mind'
require 'legion/extensions/theory_of_mind/client'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed
end

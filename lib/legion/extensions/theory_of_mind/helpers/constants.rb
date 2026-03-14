# frozen_string_literal: true

module Legion
  module Extensions
    module TheoryOfMind
      module Helpers
        module Constants
          MAX_AGENT_MODELS = 100

          MAX_BELIEFS_PER_AGENT = 50

          MAX_DESIRES_PER_AGENT = 20

          MAX_INTENTIONS_PER_AGENT = 10

          BELIEF_DECAY_RATE = 0.01

          CONFIDENCE_THRESHOLD = 0.3

          PREDICTION_ALPHA = 0.15

          STALE_BELIEF_THRESHOLD = 3600

          PERSPECTIVE_DIMENSIONS = %i[
            knowledge
            goals
            emotional_state
            constraints
            recent_actions
          ].freeze

          BELIEF_SOURCES = %i[
            direct_observation
            communication
            inference
            reputation
            behavioral_pattern
          ].freeze

          INTENTION_CONFIDENCE_LEVELS = {
            certain:  0.9,
            likely:   0.7,
            possible: 0.5,
            unlikely: 0.3,
            unknown:  0.1
          }.freeze

          DESIRE_PRIORITIES = {
            critical: 1.0,
            high:     0.75,
            medium:   0.5,
            low:      0.25,
            latent:   0.1
          }.freeze

          PREDICTION_OUTCOMES = %i[
            correct
            partially_correct
            incorrect
            unresolved
          ].freeze
        end
      end
    end
  end
end

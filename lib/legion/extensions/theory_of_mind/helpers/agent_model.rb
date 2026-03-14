# frozen_string_literal: true

module Legion
  module Extensions
    module TheoryOfMind
      module Helpers
        class AgentModel
          attr_reader :agent_id, :beliefs, :desires, :intentions,
                      :prediction_accuracy, :interaction_count, :created_at, :updated_at

          def initialize(agent_id)
            @agent_id            = agent_id
            @beliefs             = {}
            @desires             = []
            @intentions          = []
            @prediction_accuracy = 0.5
            @interaction_count   = 0
            @created_at          = Time.now.utc
            @updated_at          = Time.now.utc
          end

          def update_belief(domain:, content:, confidence:, source: :inference)
            @beliefs[domain] = {
              content:    content,
              confidence: confidence.clamp(0.0, 1.0),
              source:     source,
              updated_at: Time.now.utc
            }
            trim_beliefs
            touch
          end

          def update_desire(goal:, priority: :medium)
            existing = @desires.find { |d| d[:goal] == goal }
            if existing
              existing[:priority]    = priority
              existing[:observed_at] = Time.now.utc
            else
              @desires << { goal: goal, priority: priority, observed_at: Time.now.utc }
              trim_desires
            end
            touch
          end

          def update_intention(action:, confidence: :possible)
            existing = @intentions.find { |i| i[:action] == action }
            if existing
              existing[:confidence]    = confidence
              existing[:estimated_at]  = Time.now.utc
            else
              @intentions << { action: action, confidence: confidence, estimated_at: Time.now.utc }
              trim_intentions
            end
            touch
          end

          def belief_for(domain)
            @beliefs[domain]
          end

          def strongest_desire
            @desires.max_by { |d| Constants::DESIRE_PRIORITIES[d[:priority]] || 0 }
          end

          def most_likely_intention
            @intentions.max_by { |i| Constants::INTENTION_CONFIDENCE_LEVELS[i[:confidence]] || 0 }
          end

          def false_beliefs(known_truths)
            @beliefs.each_with_object({}) do |(domain, belief), result|
              truth = known_truths[domain]
              next unless truth
              next if truth == belief[:content]

              result[domain] = {
                agent_believes: belief[:content],
                actual_truth:   truth,
                confidence:     belief[:confidence]
              }
            end
          end

          def update_prediction_accuracy(outcome)
            score = case outcome
                    when :correct           then 1.0
                    when :partially_correct then 0.5
                    when :incorrect         then 0.0
                    else return
                    end
            alpha = Constants::PREDICTION_ALPHA
            @prediction_accuracy = (@prediction_accuracy * (1.0 - alpha)) + (score * alpha)
            @interaction_count += 1
            touch
          end

          def decay_beliefs
            @beliefs.each do |domain, belief|
              belief[:confidence] -= Constants::BELIEF_DECAY_RATE
              @beliefs.delete(domain) if belief[:confidence] < Constants::CONFIDENCE_THRESHOLD
            end
          end

          def perspective
            {
              knowledge:       @beliefs.transform_values { |b| b[:content] },
              goals:           @desires.map { |d| d[:goal] },
              emotional_state: infer_emotional_state,
              constraints:     infer_constraints,
              recent_actions:  @intentions.last(5).map { |i| i[:action] }
            }
          end

          def to_h
            {
              agent_id:            @agent_id,
              belief_count:        @beliefs.size,
              desire_count:        @desires.size,
              intention_count:     @intentions.size,
              prediction_accuracy: @prediction_accuracy.round(4),
              interaction_count:   @interaction_count,
              strongest_desire:    strongest_desire&.dig(:goal),
              likely_action:       most_likely_intention&.dig(:action)
            }
          end

          private

          def touch
            @updated_at = Time.now.utc
          end

          def infer_emotional_state
            return :unknown if @beliefs.empty? && @desires.empty?

            conflict_count = @desires.count { |d| d[:priority] == :critical }
            return :stressed if conflict_count > 1

            :stable
          end

          def infer_constraints
            low_confidence = @beliefs.count { |_, b| b[:confidence] < 0.5 }
            { uncertain_domains: low_confidence, total_beliefs: @beliefs.size }
          end

          def trim_beliefs
            return if @beliefs.size <= Constants::MAX_BELIEFS_PER_AGENT

            sorted = @beliefs.sort_by { |_, b| b[:confidence] }
            sorted.first(@beliefs.size - Constants::MAX_BELIEFS_PER_AGENT).each { |domain, _| @beliefs.delete(domain) } # rubocop:disable Style/HashEachMethods
          end

          def trim_desires
            return if @desires.size <= Constants::MAX_DESIRES_PER_AGENT

            @desires.sort_by! { |d| -(Constants::DESIRE_PRIORITIES[d[:priority]] || 0) }
            @desires.slice!(Constants::MAX_DESIRES_PER_AGENT..)
          end

          def trim_intentions
            return if @intentions.size <= Constants::MAX_INTENTIONS_PER_AGENT

            @intentions.shift(@intentions.size - Constants::MAX_INTENTIONS_PER_AGENT)
          end
        end
      end
    end
  end
end

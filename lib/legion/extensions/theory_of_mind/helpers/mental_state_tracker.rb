# frozen_string_literal: true

module Legion
  module Extensions
    module TheoryOfMind
      module Helpers
        class MentalStateTracker
          attr_reader :agent_models, :prediction_log

          def initialize
            @agent_models = {}
            @prediction_log = []
          end

          def model_for(agent_id)
            @agent_models[agent_id] ||= AgentModel.new(agent_id)
            trim_models
            @agent_models[agent_id]
          end

          def update_belief(agent_id:, domain:, content:, confidence:, source: :inference)
            model = model_for(agent_id)
            model.update_belief(domain: domain, content: content, confidence: confidence, source: source)
          end

          def update_desire(agent_id:, goal:, priority: :medium)
            model = model_for(agent_id)
            model.update_desire(goal: goal, priority: priority)
          end

          def infer_intention(agent_id:, action:, confidence: :possible)
            model = model_for(agent_id)
            model.update_intention(action: action, confidence: confidence)
          end

          def predict_behavior(agent_id:, context: {})
            model = @agent_models[agent_id]
            return nil unless model

            intention = model.most_likely_intention
            desire    = model.strongest_desire

            prediction = {
              agent_id:           agent_id,
              predicted_action:   intention&.dig(:action),
              action_confidence:  intention&.dig(:confidence),
              underlying_desire:  desire&.dig(:goal),
              context_considered: context.keys,
              model_accuracy:     model.prediction_accuracy.round(4),
              interactions_seen:  model.interaction_count
            }

            @prediction_log << prediction.merge(predicted_at: Time.now.utc)
            trim_prediction_log

            prediction
          end

          def record_prediction_outcome(agent_id:, outcome:)
            model = @agent_models[agent_id]
            return nil unless model

            model.update_prediction_accuracy(outcome)
          end

          def false_belief_check(agent_id:, known_truths:)
            model = @agent_models[agent_id]
            return nil unless model

            model.false_beliefs(known_truths)
          end

          def perspective_take(agent_id:)
            model = @agent_models[agent_id]
            return nil unless model

            model.perspective
          end

          def compare_agents(agent_ids:)
            models = agent_ids.filter_map { |id| @agent_models[id] }
            return nil if models.empty?

            {
              agents:            models.map(&:to_h),
              shared_beliefs:    find_shared_beliefs(models),
              conflicting_goals: find_conflicting_goals(models),
              interaction_gap:   interaction_gap(models)
            }
          end

          def decay_all
            @agent_models.each_value(&:decay_beliefs)
            @agent_models.reject! { |_, m| m.beliefs.empty? && m.desires.empty? && m.intentions.empty? }
          end

          def agents_tracked
            @agent_models.size
          end

          def total_beliefs
            @agent_models.values.sum { |m| m.beliefs.size }
          end

          def avg_prediction_accuracy
            return 0.0 if @agent_models.empty?

            total = @agent_models.values.sum(&:prediction_accuracy)
            (total / @agent_models.size).round(4)
          end

          def to_h
            {
              agents_tracked:          agents_tracked,
              total_beliefs:           total_beliefs,
              avg_prediction_accuracy: avg_prediction_accuracy,
              prediction_log_size:     @prediction_log.size
            }
          end

          private

          def find_shared_beliefs(models)
            return [] if models.size < 2

            domains = models.map { |m| m.beliefs.keys }
            shared  = domains.reduce(:&) || []
            shared.map do |domain|
              values = models.map { |m| m.belief_for(domain)[:content] }
              { domain: domain, values: values, consensus: values.uniq.size == 1 }
            end
          end

          def find_conflicting_goals(models)
            return [] if models.size < 2

            all_goals = models.flat_map { |m| m.desires.map { |d| { agent: m.agent_id, goal: d[:goal], priority: d[:priority] } } }
            goal_groups = all_goals.group_by { |g| g[:goal] }
            goal_groups.select { |_, entries| entries.size > 1 }.map do |goal, entries|
              { goal: goal, agents: entries.map { |e| e[:agent] } }
            end
          end

          def interaction_gap(models)
            counts = models.map(&:interaction_count)
            return 0 if counts.empty?

            counts.max - counts.min
          end

          def trim_models
            return if @agent_models.size <= Constants::MAX_AGENT_MODELS

            oldest = @agent_models.sort_by { |_, m| m.updated_at }
            oldest.first(@agent_models.size - Constants::MAX_AGENT_MODELS).each { |id, _| @agent_models.delete(id) } # rubocop:disable Style/HashEachMethods
          end

          def trim_prediction_log
            @prediction_log.shift while @prediction_log.size > 200
          end
        end
      end
    end
  end
end

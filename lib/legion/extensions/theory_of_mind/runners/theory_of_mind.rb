# frozen_string_literal: true

module Legion
  module Extensions
    module TheoryOfMind
      module Runners
        module TheoryOfMind
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def update_theory_of_mind(tick_results: {}, **)
            extract_social_observations(tick_results)
            extract_mesh_observations(tick_results)
            tracker.decay_all

            Legion::Logging.debug "[tom] agents=#{tracker.agents_tracked} " \
                                  "beliefs=#{tracker.total_beliefs} accuracy=#{tracker.avg_prediction_accuracy}"

            tracker.to_h
          end

          def observe_agent(agent_id:, observations: {}, **)
            apply_belief_observation(agent_id, observations)
            apply_desire_observation(agent_id, observations)
            apply_intention_observation(agent_id, observations)

            Legion::Logging.debug "[tom] observed agent=#{agent_id}"
            { success: true, model: tracker.model_for(agent_id).to_h }
          end

          def predict_behavior(agent_id:, context: {}, **)
            prediction = tracker.predict_behavior(agent_id: agent_id, context: context)
            return { error: 'unknown agent' } unless prediction

            Legion::Logging.debug "[tom] predicted action for #{agent_id}: #{prediction[:predicted_action]}"
            prediction
          end

          def record_outcome(agent_id:, outcome:, **)
            result = tracker.record_prediction_outcome(agent_id: agent_id, outcome: outcome.to_sym)
            return { error: 'unknown agent' } unless result

            Legion::Logging.debug "[tom] outcome for #{agent_id}: #{outcome}"
            { success: true, accuracy: tracker.model_for(agent_id).prediction_accuracy.round(4) }
          end

          def check_false_beliefs(agent_id:, known_truths:, **)
            false_beliefs = tracker.false_belief_check(agent_id: agent_id, known_truths: known_truths)
            return { error: 'unknown agent' } unless false_beliefs

            Legion::Logging.debug "[tom] false beliefs for #{agent_id}: #{false_beliefs.size}"
            { agent_id: agent_id, false_beliefs: false_beliefs, count: false_beliefs.size }
          end

          def perspective_take(agent_id:, **)
            perspective = tracker.perspective_take(agent_id: agent_id)
            return { error: 'unknown agent' } unless perspective

            Legion::Logging.debug "[tom] perspective for #{agent_id}"
            { agent_id: agent_id, perspective: perspective }
          end

          def compare_agents(agent_ids:, **)
            comparison = tracker.compare_agents(agent_ids: agent_ids)
            return { error: 'no matching agents' } unless comparison

            Legion::Logging.debug "[tom] comparing #{agent_ids.size} agents"
            comparison
          end

          def mental_state(agent_id:, **)
            model = tracker.agent_models[agent_id]
            return { error: 'unknown agent' } unless model

            {
              agent_id:    agent_id,
              beliefs:     model.beliefs.transform_values { |b| { content: b[:content], confidence: b[:confidence].round(4) } },
              desires:     model.desires,
              intentions:  model.intentions,
              accuracy:    model.prediction_accuracy.round(4),
              perspective: model.perspective
            }
          end

          def tom_stats(**)
            Legion::Logging.debug '[tom] stats'
            tracker.to_h.merge(
              models: tracker.agent_models.transform_values(&:to_h)
            )
          end

          private

          def tracker
            @tracker ||= Helpers::MentalStateTracker.new
          end

          def apply_belief_observation(agent_id, obs)
            return unless obs[:domain] && obs[:belief]

            tracker.update_belief(
              agent_id:   agent_id,
              domain:     obs[:domain],
              content:    obs[:belief],
              confidence: obs[:confidence] || 0.5,
              source:     obs[:source] || :inference
            )
          end

          def apply_desire_observation(agent_id, obs)
            return unless obs[:goal]

            tracker.update_desire(agent_id: agent_id, goal: obs[:goal], priority: obs[:goal_priority] || :medium)
          end

          def apply_intention_observation(agent_id, obs)
            return unless obs[:action]

            tracker.infer_intention(agent_id: agent_id, action: obs[:action], confidence: obs[:action_confidence] || :possible)
          end

          def extract_social_observations(tick_results)
            social = tick_results.dig(:social, :reputation_updates)
            return unless social.is_a?(Array)

            social.each do |update|
              tracker.update_belief(
                agent_id:   update[:agent_id],
                domain:     :social_standing,
                content:    update[:standing],
                confidence: update[:composite] || 0.5,
                source:     :direct_observation
              )
            end
          end

          def extract_mesh_observations(tick_results)
            messages = tick_results.dig(:mesh_interface, :received_messages)
            return unless messages.is_a?(Array)

            messages.each do |msg|
              next unless msg[:from]

              tracker.infer_intention(
                agent_id:   msg[:from],
                action:     msg[:type] || :communicate,
                confidence: :likely
              )
            end
          end
        end
      end
    end
  end
end

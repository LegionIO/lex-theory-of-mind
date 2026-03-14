# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::TheoryOfMind::Runners::TheoryOfMind do
  let(:mental_tracker) { Legion::Extensions::TheoryOfMind::Helpers::MentalStateTracker.new }

  let(:host) do
    Object.new.tap do |obj|
      obj.extend(described_class)
      obj.instance_variable_set(:@tracker, mental_tracker)
    end
  end

  describe '#observe_agent' do
    it 'records a belief' do
      result = host.observe_agent(agent_id: :a1, observations: { domain: :location, belief: 'office', confidence: 0.9 })
      expect(result[:success]).to be true
      expect(mental_tracker.agent_models[:a1].beliefs[:location][:content]).to eq('office')
    end

    it 'records a desire' do
      result = host.observe_agent(agent_id: :a1, observations: { goal: 'deploy' })
      expect(result[:success]).to be true
    end

    it 'records an intention' do
      result = host.observe_agent(agent_id: :a1, observations: { action: :send_message, action_confidence: :certain })
      expect(result[:success]).to be true
    end

    it 'records all three at once' do
      host.observe_agent(
        agent_id:     :a1,
        observations: {
          domain: :mood, belief: 'happy', confidence: 0.8,
          goal: 'rest', goal_priority: :low,
          action: :idle, action_confidence: :likely
        }
      )
      model = mental_tracker.agent_models[:a1]
      expect(model.beliefs[:mood][:content]).to eq('happy')
      expect(model.desires.first[:goal]).to eq('rest')
      expect(model.intentions.first[:action]).to eq(:idle)
    end

    it 'returns the updated model summary' do
      result = host.observe_agent(agent_id: :a1, observations: { domain: :x, belief: 'y', confidence: 0.5 })
      expect(result[:model]).to have_key(:agent_id)
      expect(result[:model][:belief_count]).to eq(1)
    end
  end

  describe '#predict_behavior' do
    before do
      host.observe_agent(agent_id: :a1, observations: { goal: 'optimize', action: :refactor, action_confidence: :certain })
    end

    it 'returns a prediction' do
      result = host.predict_behavior(agent_id: :a1)
      expect(result[:predicted_action]).to eq(:refactor)
      expect(result[:underlying_desire]).to eq('optimize')
    end

    it 'returns error for unknown agent' do
      result = host.predict_behavior(agent_id: :unknown)
      expect(result[:error]).to eq('unknown agent')
    end
  end

  describe '#record_outcome' do
    before do
      host.observe_agent(agent_id: :a1, observations: { domain: :x, belief: 'y', confidence: 0.5 })
    end

    it 'returns success with updated accuracy' do
      result = host.record_outcome(agent_id: :a1, outcome: :correct)
      expect(result[:success]).to be true
      expect(result[:accuracy]).to be > 0.5
    end

    it 'accepts string outcomes' do
      result = host.record_outcome(agent_id: :a1, outcome: 'incorrect')
      expect(result[:success]).to be true
    end

    it 'returns error for unknown agent' do
      result = host.record_outcome(agent_id: :unknown, outcome: :correct)
      expect(result[:error]).to eq('unknown agent')
    end
  end

  describe '#check_false_beliefs' do
    before do
      host.observe_agent(agent_id: :a1, observations: { domain: :weather, belief: 'sunny', confidence: 0.9 })
      host.observe_agent(agent_id: :a1, observations: { domain: :day, belief: 'monday', confidence: 0.8 })
    end

    it 'identifies false beliefs' do
      result = host.check_false_beliefs(agent_id: :a1, known_truths: { weather: 'rainy', day: 'monday' })
      expect(result[:count]).to eq(1)
      expect(result[:false_beliefs]).to have_key(:weather)
    end

    it 'returns error for unknown agent' do
      result = host.check_false_beliefs(agent_id: :unknown, known_truths: {})
      expect(result[:error]).to eq('unknown agent')
    end
  end

  describe '#perspective_take' do
    before do
      host.observe_agent(agent_id: :a1, observations: { domain: :task, belief: 'coding', confidence: 0.9, goal: 'ship' })
    end

    it 'returns the perspective' do
      result = host.perspective_take(agent_id: :a1)
      expect(result[:agent_id]).to eq(:a1)
      expect(result[:perspective][:knowledge][:task]).to eq('coding')
      expect(result[:perspective][:goals]).to include('ship')
    end

    it 'returns error for unknown agent' do
      result = host.perspective_take(agent_id: :unknown)
      expect(result[:error]).to eq('unknown agent')
    end
  end

  describe '#compare_agents' do
    before do
      host.observe_agent(agent_id: :a1, observations: { domain: :lang, belief: 'ruby', confidence: 0.9, goal: 'refactor' })
      host.observe_agent(agent_id: :a2, observations: { domain: :lang, belief: 'ruby', confidence: 0.8, goal: 'refactor' })
    end

    it 'returns comparison data' do
      result = host.compare_agents(agent_ids: %i[a1 a2])
      expect(result[:agents].size).to eq(2)
      expect(result[:shared_beliefs]).not_to be_empty
    end

    it 'returns error when no agents match' do
      result = host.compare_agents(agent_ids: %i[x1 x2])
      expect(result[:error]).to eq('no matching agents')
    end
  end

  describe '#mental_state' do
    before do
      host.observe_agent(agent_id: :a1, observations: { domain: :role, belief: 'dev', confidence: 0.8, goal: 'learn' })
    end

    it 'returns full mental state' do
      result = host.mental_state(agent_id: :a1)
      expect(result[:agent_id]).to eq(:a1)
      expect(result[:beliefs]).to have_key(:role)
      expect(result[:desires]).not_to be_empty
      expect(result[:perspective]).to be_a(Hash)
    end

    it 'returns error for unknown agent' do
      result = host.mental_state(agent_id: :unknown)
      expect(result[:error]).to eq('unknown agent')
    end
  end

  describe '#tom_stats' do
    it 'returns aggregate statistics' do
      host.observe_agent(agent_id: :a1, observations: { domain: :x, belief: 'y', confidence: 0.5 })
      result = host.tom_stats
      expect(result[:agents_tracked]).to eq(1)
      expect(result[:total_beliefs]).to eq(1)
      expect(result[:models]).to be_a(Hash)
    end
  end

  describe '#update_theory_of_mind' do
    it 'returns tracker summary' do
      result = host.update_theory_of_mind(tick_results: {})
      expect(result).to have_key(:agents_tracked)
    end

    it 'extracts social observations from tick results' do
      tick = {
        social: {
          reputation_updates: [
            { agent_id: :a1, standing: :respected, composite: 0.7 },
            { agent_id: :a2, standing: :neutral, composite: 0.5 }
          ]
        }
      }
      host.update_theory_of_mind(tick_results: tick)
      expect(mental_tracker.agents_tracked).to eq(2)
      expect(mental_tracker.agent_models[:a1].beliefs[:social_standing][:content]).to eq(:respected)
    end

    it 'extracts mesh observations from tick results' do
      tick = {
        mesh_interface: {
          received_messages: [
            { from: :a1, type: :request },
            { from: :a2, type: :broadcast }
          ]
        }
      }
      host.update_theory_of_mind(tick_results: tick)
      expect(mental_tracker.agent_models[:a1].intentions.first[:action]).to eq(:request)
    end

    it 'handles empty tick results' do
      result = host.update_theory_of_mind(tick_results: {})
      expect(result[:agents_tracked]).to eq(0)
    end

    it 'decays beliefs during tick' do
      host.observe_agent(agent_id: :a1, observations: { domain: :test, belief: 'val', confidence: 0.5 })
      initial = mental_tracker.agent_models[:a1].beliefs[:test][:confidence]
      host.update_theory_of_mind(tick_results: {})
      expect(mental_tracker.agent_models[:a1].beliefs[:test][:confidence]).to be < initial
    end
  end
end

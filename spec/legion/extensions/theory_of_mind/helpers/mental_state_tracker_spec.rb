# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::TheoryOfMind::Helpers::MentalStateTracker do
  subject(:tracker) { described_class.new }

  describe '#initialize' do
    it 'starts with empty agent models' do
      expect(tracker.agent_models).to be_empty
    end

    it 'starts with empty prediction log' do
      expect(tracker.prediction_log).to be_empty
    end
  end

  describe '#model_for' do
    it 'creates a new model for unknown agent' do
      model = tracker.model_for(:a1)
      expect(model).to be_a(Legion::Extensions::TheoryOfMind::Helpers::AgentModel)
      expect(model.agent_id).to eq(:a1)
    end

    it 'returns the same model on repeat call' do
      model1 = tracker.model_for(:a1)
      model2 = tracker.model_for(:a1)
      expect(model1).to equal(model2)
    end

    it 'trims models beyond MAX_AGENT_MODELS' do
      max = Legion::Extensions::TheoryOfMind::Helpers::Constants::MAX_AGENT_MODELS
      (max + 5).times { |i| tracker.model_for(:"agent_#{i}") }
      expect(tracker.agents_tracked).to eq(max)
    end
  end

  describe '#update_belief' do
    it 'stores a belief on the agent model' do
      tracker.update_belief(agent_id: :a1, domain: :skill, content: 'expert', confidence: 0.9)
      model = tracker.agent_models[:a1]
      expect(model.beliefs[:skill][:content]).to eq('expert')
    end
  end

  describe '#update_desire' do
    it 'stores a desire on the agent model' do
      tracker.update_desire(agent_id: :a1, goal: 'deploy', priority: :high)
      model = tracker.agent_models[:a1]
      expect(model.desires.first[:goal]).to eq('deploy')
    end
  end

  describe '#infer_intention' do
    it 'stores an intention on the agent model' do
      tracker.infer_intention(agent_id: :a1, action: :request_help, confidence: :likely)
      model = tracker.agent_models[:a1]
      expect(model.intentions.first[:action]).to eq(:request_help)
    end
  end

  describe '#predict_behavior' do
    before do
      tracker.update_desire(agent_id: :a1, goal: 'optimize', priority: :critical)
      tracker.infer_intention(agent_id: :a1, action: :refactor, confidence: :certain)
    end

    it 'returns a prediction hash' do
      result = tracker.predict_behavior(agent_id: :a1)
      expect(result[:predicted_action]).to eq(:refactor)
      expect(result[:underlying_desire]).to eq('optimize')
    end

    it 'adds to prediction log' do
      tracker.predict_behavior(agent_id: :a1)
      expect(tracker.prediction_log.size).to eq(1)
    end

    it 'returns nil for unknown agent' do
      expect(tracker.predict_behavior(agent_id: :unknown)).to be_nil
    end

    it 'includes model accuracy' do
      result = tracker.predict_behavior(agent_id: :a1)
      expect(result[:model_accuracy]).to be_a(Float)
    end
  end

  describe '#record_prediction_outcome' do
    before { tracker.model_for(:a1) }

    it 'updates the model prediction accuracy' do
      initial = tracker.agent_models[:a1].prediction_accuracy
      tracker.record_prediction_outcome(agent_id: :a1, outcome: :correct)
      expect(tracker.agent_models[:a1].prediction_accuracy).to be > initial
    end

    it 'returns nil for unknown agent' do
      expect(tracker.record_prediction_outcome(agent_id: :unknown, outcome: :correct)).to be_nil
    end
  end

  describe '#false_belief_check' do
    before do
      tracker.update_belief(agent_id: :a1, domain: :status, content: 'online', confidence: 0.8)
    end

    it 'identifies false beliefs' do
      result = tracker.false_belief_check(agent_id: :a1, known_truths: { status: 'offline' })
      expect(result).to have_key(:status)
      expect(result[:status][:agent_believes]).to eq('online')
    end

    it 'returns empty hash when beliefs are correct' do
      result = tracker.false_belief_check(agent_id: :a1, known_truths: { status: 'online' })
      expect(result).to be_empty
    end

    it 'returns nil for unknown agent' do
      expect(tracker.false_belief_check(agent_id: :unknown, known_truths: {})).to be_nil
    end
  end

  describe '#perspective_take' do
    before do
      tracker.update_belief(agent_id: :a1, domain: :task, content: 'building', confidence: 0.9)
      tracker.update_desire(agent_id: :a1, goal: 'ship_feature', priority: :high)
    end

    it 'returns the perspective hash' do
      result = tracker.perspective_take(agent_id: :a1)
      expect(result[:knowledge][:task]).to eq('building')
      expect(result[:goals]).to include('ship_feature')
    end

    it 'returns nil for unknown agent' do
      expect(tracker.perspective_take(agent_id: :unknown)).to be_nil
    end
  end

  describe '#compare_agents' do
    before do
      tracker.update_belief(agent_id: :a1, domain: :color, content: 'blue', confidence: 0.9)
      tracker.update_belief(agent_id: :a2, domain: :color, content: 'blue', confidence: 0.8)
      tracker.update_desire(agent_id: :a1, goal: 'win', priority: :high)
      tracker.update_desire(agent_id: :a2, goal: 'win', priority: :critical)
    end

    it 'returns a comparison hash' do
      result = tracker.compare_agents(agent_ids: %i[a1 a2])
      expect(result[:agents].size).to eq(2)
    end

    it 'finds shared beliefs with consensus' do
      result = tracker.compare_agents(agent_ids: %i[a1 a2])
      shared = result[:shared_beliefs].find { |s| s[:domain] == :color }
      expect(shared[:consensus]).to be true
    end

    it 'finds conflicting goals' do
      result = tracker.compare_agents(agent_ids: %i[a1 a2])
      expect(result[:conflicting_goals]).not_to be_empty
    end

    it 'returns nil when no agents match' do
      expect(tracker.compare_agents(agent_ids: %i[unknown1 unknown2])).to be_nil
    end
  end

  describe '#decay_all' do
    it 'decays beliefs across all models' do
      tracker.update_belief(agent_id: :a1, domain: :test, content: 'val', confidence: 0.5)
      initial = tracker.agent_models[:a1].beliefs[:test][:confidence]
      tracker.decay_all
      expect(tracker.agent_models[:a1].beliefs[:test][:confidence]).to be < initial
    end

    it 'removes models with no state left' do
      threshold = Legion::Extensions::TheoryOfMind::Helpers::Constants::CONFIDENCE_THRESHOLD
      tracker.update_belief(agent_id: :weak, domain: :x, content: 'v', confidence: threshold + 0.005)
      tracker.decay_all
      expect(tracker.agent_models).not_to have_key(:weak)
    end
  end

  describe '#agents_tracked' do
    it 'returns 0 initially' do
      expect(tracker.agents_tracked).to eq(0)
    end

    it 'counts tracked agents' do
      tracker.model_for(:a1)
      tracker.model_for(:a2)
      expect(tracker.agents_tracked).to eq(2)
    end
  end

  describe '#total_beliefs' do
    it 'sums beliefs across all models' do
      tracker.update_belief(agent_id: :a1, domain: :x, content: 'v', confidence: 0.9)
      tracker.update_belief(agent_id: :a1, domain: :y, content: 'v', confidence: 0.9)
      tracker.update_belief(agent_id: :a2, domain: :z, content: 'v', confidence: 0.9)
      expect(tracker.total_beliefs).to eq(3)
    end
  end

  describe '#avg_prediction_accuracy' do
    it 'returns 0.0 when empty' do
      expect(tracker.avg_prediction_accuracy).to eq(0.0)
    end

    it 'averages accuracy across models' do
      tracker.model_for(:a1)
      tracker.model_for(:a2)
      expect(tracker.avg_prediction_accuracy).to eq(0.5)
    end
  end

  describe '#to_h' do
    it 'returns a summary hash' do
      result = tracker.to_h
      expect(result).to have_key(:agents_tracked)
      expect(result).to have_key(:total_beliefs)
      expect(result).to have_key(:avg_prediction_accuracy)
      expect(result).to have_key(:prediction_log_size)
    end
  end
end

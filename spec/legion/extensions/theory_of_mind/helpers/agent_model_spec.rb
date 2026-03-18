# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::TheoryOfMind::Helpers::AgentModel do
  subject(:model) { described_class.new(:agent_alpha) }

  describe '#initialize' do
    it 'sets the agent_id' do
      expect(model.agent_id).to eq(:agent_alpha)
    end

    it 'starts with empty beliefs' do
      expect(model.beliefs).to be_empty
    end

    it 'starts with empty desires' do
      expect(model.desires).to be_empty
    end

    it 'starts with empty intentions' do
      expect(model.intentions).to be_empty
    end

    it 'starts with 0.5 prediction accuracy' do
      expect(model.prediction_accuracy).to eq(0.5)
    end
  end

  describe '#update_belief' do
    it 'stores a belief for the domain' do
      model.update_belief(domain: :location, content: 'office', confidence: 0.8)
      expect(model.beliefs[:location][:content]).to eq('office')
    end

    it 'clamps confidence to 0..1' do
      model.update_belief(domain: :mood, content: 'happy', confidence: 5.0)
      expect(model.beliefs[:mood][:confidence]).to eq(1.0)
    end

    it 'records the source' do
      model.update_belief(domain: :role, content: 'leader', confidence: 0.7, source: :direct_observation)
      expect(model.beliefs[:role][:source]).to eq(:direct_observation)
    end

    it 'overwrites existing belief for same domain' do
      model.update_belief(domain: :location, content: 'office', confidence: 0.8)
      model.update_belief(domain: :location, content: 'home', confidence: 0.9)
      expect(model.beliefs[:location][:content]).to eq('home')
    end

    it 'trims beliefs beyond MAX_BELIEFS_PER_AGENT' do
      max = Legion::Extensions::TheoryOfMind::Helpers::Constants::MAX_BELIEFS_PER_AGENT
      (max + 5).times { |i| model.update_belief(domain: :"domain_#{i}", content: "val_#{i}", confidence: 0.5 + (i * 0.001)) }
      expect(model.beliefs.size).to eq(max)
    end
  end

  describe '#update_desire' do
    it 'adds a new desire' do
      model.update_desire(goal: 'complete_task')
      expect(model.desires.size).to eq(1)
    end

    it 'defaults priority to medium' do
      model.update_desire(goal: 'learn')
      expect(model.desires.first[:priority]).to eq(:medium)
    end

    it 'updates existing desire priority' do
      model.update_desire(goal: 'learn', priority: :low)
      model.update_desire(goal: 'learn', priority: :critical)
      expect(model.desires.size).to eq(1)
      expect(model.desires.first[:priority]).to eq(:critical)
    end

    it 'trims desires beyond MAX_DESIRES_PER_AGENT' do
      max = Legion::Extensions::TheoryOfMind::Helpers::Constants::MAX_DESIRES_PER_AGENT
      (max + 5).times { |i| model.update_desire(goal: "goal_#{i}") }
      expect(model.desires.size).to eq(max)
    end
  end

  describe '#update_intention' do
    it 'adds a new intention' do
      model.update_intention(action: :send_message, confidence: :likely)
      expect(model.intentions.size).to eq(1)
    end

    it 'updates existing intention confidence' do
      model.update_intention(action: :send_message, confidence: :possible)
      model.update_intention(action: :send_message, confidence: :certain)
      expect(model.intentions.size).to eq(1)
      expect(model.intentions.first[:confidence]).to eq(:certain)
    end

    it 'trims intentions beyond MAX_INTENTIONS_PER_AGENT' do
      max = Legion::Extensions::TheoryOfMind::Helpers::Constants::MAX_INTENTIONS_PER_AGENT
      (max + 3).times { |i| model.update_intention(action: :"action_#{i}") }
      expect(model.intentions.size).to eq(max)
    end
  end

  describe '#belief_for' do
    it 'returns the belief for a domain' do
      model.update_belief(domain: :location, content: 'lab', confidence: 0.9)
      expect(model.belief_for(:location)[:content]).to eq('lab')
    end

    it 'returns nil for unknown domain' do
      expect(model.belief_for(:unknown)).to be_nil
    end
  end

  describe '#strongest_desire' do
    it 'returns the highest-priority desire' do
      model.update_desire(goal: 'rest', priority: :low)
      model.update_desire(goal: 'work', priority: :critical)
      model.update_desire(goal: 'eat', priority: :medium)
      expect(model.strongest_desire[:goal]).to eq('work')
    end

    it 'returns nil when no desires' do
      expect(model.strongest_desire).to be_nil
    end
  end

  describe '#most_likely_intention' do
    it 'returns the highest-confidence intention' do
      model.update_intention(action: :wait, confidence: :unlikely)
      model.update_intention(action: :attack, confidence: :certain)
      model.update_intention(action: :flee, confidence: :possible)
      expect(model.most_likely_intention[:action]).to eq(:attack)
    end

    it 'returns nil when no intentions' do
      expect(model.most_likely_intention).to be_nil
    end
  end

  describe '#false_beliefs' do
    before do
      model.update_belief(domain: :weather, content: 'sunny', confidence: 0.8)
      model.update_belief(domain: :time, content: 'morning', confidence: 0.7)
    end

    it 'identifies beliefs that contradict known truths' do
      truths = { weather: 'rainy', time: 'morning' }
      result = model.false_beliefs(truths)
      expect(result).to have_key(:weather)
      expect(result[:weather][:agent_believes]).to eq('sunny')
      expect(result[:weather][:actual_truth]).to eq('rainy')
    end

    it 'does not flag correct beliefs' do
      truths = { weather: 'sunny' }
      result = model.false_beliefs(truths)
      expect(result).to be_empty
    end

    it 'ignores domains not in known truths' do
      truths = { unrelated: 'value' }
      result = model.false_beliefs(truths)
      expect(result).to be_empty
    end
  end

  describe '#update_prediction_accuracy' do
    it 'increases accuracy on correct predictions' do
      initial = model.prediction_accuracy
      model.update_prediction_accuracy(:correct)
      expect(model.prediction_accuracy).to be > initial
    end

    it 'decreases accuracy on incorrect predictions' do
      initial = model.prediction_accuracy
      model.update_prediction_accuracy(:incorrect)
      expect(model.prediction_accuracy).to be < initial
    end

    it 'increments interaction count' do
      model.update_prediction_accuracy(:correct)
      expect(model.interaction_count).to eq(1)
    end

    it 'ignores unknown outcomes' do
      model.update_prediction_accuracy(:nonsense)
      expect(model.interaction_count).to eq(0)
    end
  end

  describe '#decay_beliefs' do
    it 'reduces belief confidence' do
      model.update_belief(domain: :test, content: 'val', confidence: 0.5)
      initial = model.beliefs[:test][:confidence]
      model.decay_beliefs
      expect(model.beliefs[:test][:confidence]).to be < initial
    end

    it 'removes beliefs below CONFIDENCE_THRESHOLD' do
      threshold = Legion::Extensions::TheoryOfMind::Helpers::Constants::CONFIDENCE_THRESHOLD
      model.update_belief(domain: :weak, content: 'val', confidence: threshold + 0.005)
      model.decay_beliefs
      expect(model.beliefs).not_to have_key(:weak)
    end

    it 'removes stale beliefs older than STALE_BELIEF_THRESHOLD' do
      model.update_belief(domain: :stale, content: 'old', confidence: 0.9)
      stale_threshold = Legion::Extensions::TheoryOfMind::Helpers::Constants::STALE_BELIEF_THRESHOLD
      model.beliefs[:stale][:updated_at] = Time.now.utc - stale_threshold - 1
      model.decay_beliefs
      expect(model.beliefs).not_to have_key(:stale)
    end

    it 'keeps recent beliefs even with moderate confidence' do
      model.update_belief(domain: :fresh, content: 'new', confidence: 0.6)
      model.decay_beliefs
      expect(model.beliefs).to have_key(:fresh)
    end
  end

  describe '#perspective' do
    before do
      model.update_belief(domain: :location, content: 'office', confidence: 0.9)
      model.update_desire(goal: 'finish_report', priority: :high)
      model.update_intention(action: :write, confidence: :likely)
    end

    it 'returns knowledge from beliefs' do
      expect(model.perspective[:knowledge][:location]).to eq('office')
    end

    it 'returns goals from desires' do
      expect(model.perspective[:goals]).to include('finish_report')
    end

    it 'returns recent actions from intentions' do
      expect(model.perspective[:recent_actions]).to include(:write)
    end

    it 'includes emotional state' do
      expect(model.perspective[:emotional_state]).to be_a(Symbol)
    end

    it 'includes constraints' do
      expect(model.perspective[:constraints]).to have_key(:uncertain_domains)
    end
  end

  describe '#to_h' do
    it 'returns a summary hash' do
      result = model.to_h
      expect(result[:agent_id]).to eq(:agent_alpha)
      expect(result).to have_key(:belief_count)
      expect(result).to have_key(:prediction_accuracy)
    end
  end
end

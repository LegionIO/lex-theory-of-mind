# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::TheoryOfMind::Client do
  describe '#initialize' do
    it 'creates a default mental state tracker' do
      client = described_class.new
      expect(client.tracker).to be_a(Legion::Extensions::TheoryOfMind::Helpers::MentalStateTracker)
    end

    it 'accepts an injected tracker' do
      tracker = Legion::Extensions::TheoryOfMind::Helpers::MentalStateTracker.new
      client = described_class.new(tracker: tracker)
      expect(client.tracker).to equal(tracker)
    end

    it 'ignores unknown keyword arguments' do
      expect { described_class.new(unknown: true) }.not_to raise_error
    end
  end

  describe 'runner integration' do
    subject(:client) { described_class.new }

    it 'responds to observe_agent' do
      expect(client).to respond_to(:observe_agent)
    end

    it 'responds to predict_behavior' do
      expect(client).to respond_to(:predict_behavior)
    end

    it 'responds to check_false_beliefs' do
      expect(client).to respond_to(:check_false_beliefs)
    end

    it 'responds to perspective_take' do
      expect(client).to respond_to(:perspective_take)
    end

    it 'can perform a full ToM workflow' do
      client.observe_agent(agent_id: :bob, observations: { domain: :location, belief: 'office', confidence: 0.9 })
      client.observe_agent(agent_id: :bob, observations: { goal: 'finish_report', goal_priority: :high })
      client.observe_agent(agent_id: :bob, observations: { action: :typing, action_confidence: :certain })

      prediction = client.predict_behavior(agent_id: :bob)
      expect(prediction[:predicted_action]).to eq(:typing)
      expect(prediction[:underlying_desire]).to eq('finish_report')

      false_beliefs = client.check_false_beliefs(agent_id: :bob, known_truths: { location: 'home' })
      expect(false_beliefs[:count]).to eq(1)
      expect(false_beliefs[:false_beliefs][:location][:agent_believes]).to eq('office')

      perspective = client.perspective_take(agent_id: :bob)
      expect(perspective[:perspective][:knowledge][:location]).to eq('office')

      client.record_outcome(agent_id: :bob, outcome: :correct)
      state = client.mental_state(agent_id: :bob)
      expect(state[:accuracy]).to be > 0.5
    end
  end
end

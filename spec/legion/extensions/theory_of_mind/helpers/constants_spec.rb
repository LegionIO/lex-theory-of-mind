# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::TheoryOfMind::Helpers::Constants do
  describe 'PERSPECTIVE_DIMENSIONS' do
    it 'contains 5 dimensions' do
      expect(described_class::PERSPECTIVE_DIMENSIONS.size).to eq(5)
    end

    it 'is frozen' do
      expect(described_class::PERSPECTIVE_DIMENSIONS).to be_frozen
    end
  end

  describe 'BELIEF_SOURCES' do
    it 'contains 5 sources' do
      expect(described_class::BELIEF_SOURCES.size).to eq(5)
    end

    it 'is frozen' do
      expect(described_class::BELIEF_SOURCES).to be_frozen
    end
  end

  describe 'INTENTION_CONFIDENCE_LEVELS' do
    it 'is ordered from highest to lowest' do
      thresholds = described_class::INTENTION_CONFIDENCE_LEVELS.values
      expect(thresholds).to eq(thresholds.sort.reverse)
    end
  end

  describe 'DESIRE_PRIORITIES' do
    it 'is ordered from highest to lowest' do
      thresholds = described_class::DESIRE_PRIORITIES.values
      expect(thresholds).to eq(thresholds.sort.reverse)
    end
  end

  describe 'PREDICTION_OUTCOMES' do
    it 'contains 4 outcomes' do
      expect(described_class::PREDICTION_OUTCOMES.size).to eq(4)
    end

    it 'is frozen' do
      expect(described_class::PREDICTION_OUTCOMES).to be_frozen
    end
  end

  describe 'scalar constants' do
    it 'has positive MAX_AGENT_MODELS' do
      expect(described_class::MAX_AGENT_MODELS).to be > 0
    end

    it 'has positive MAX_BELIEFS_PER_AGENT' do
      expect(described_class::MAX_BELIEFS_PER_AGENT).to be > 0
    end

    it 'has BELIEF_DECAY_RATE between 0 and 1' do
      expect(described_class::BELIEF_DECAY_RATE).to be_between(0.0, 1.0)
    end

    it 'has CONFIDENCE_THRESHOLD between 0 and 1' do
      expect(described_class::CONFIDENCE_THRESHOLD).to be_between(0.0, 1.0)
    end

    it 'has PREDICTION_ALPHA between 0 and 1' do
      expect(described_class::PREDICTION_ALPHA).to be_between(0.0, 1.0)
    end
  end
end

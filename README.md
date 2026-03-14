# lex-theory-of-mind

Theory of Mind (ToM) for LegionIO cognitive agents. Tracks other agents' beliefs, desires, and intentions (BDI) to enable behavior prediction, false-belief detection, and perspective taking.

## What It Does

`lex-theory-of-mind` gives cognitive agents a model of what other agents know, want, and plan to do. For each observed agent, it maintains a BDI (Belief-Desire-Intention) model updated from direct observations, inference, and communication. The agent can then predict behavior, detect false beliefs (when another agent holds an incorrect belief), take their perspective, and compare mental states across agents.

- **Beliefs**: per-domain content with confidence and source attribution; decay over time
- **Desires**: goals with priority levels
- **Intentions**: inferred planned actions with confidence
- **Prediction accuracy**: EMA-tracked accuracy of behavior predictions
- **False beliefs**: beliefs the observer knows to be incorrect
- **Perspective**: five-dimensional view (spatial, temporal, epistemic, emotional, motivational)

## Usage

```ruby
require 'legion/extensions/theory_of_mind'

client = Legion::Extensions::TheoryOfMind::Client.new

# Observe another agent
client.observe_agent(
  agent_id: 'agent_bob',
  agent_name: 'Bob',
  observations: {
    beliefs: [{ domain: :weather, content: 'sunny', confidence: 0.9, source: :direct_observation }],
    desires: [{ goal: 'finish_project', priority: :high }],
    intentions: [{ action: 'write_tests', confidence: 0.7 }]
  }
)

# Predict what they'll do next
client.predict_behavior(agent_id: 'agent_bob')
# => { predicted_action: 'write_tests', confidence: 0.7 }

# Record how accurate the prediction was
client.record_outcome(agent_id: 'agent_bob', outcome: :correct)

# Check for false beliefs (things they believe that you know are wrong)
client.check_false_beliefs(
  agent_id: 'agent_bob',
  known_truths: { weather: 'rainy' }
)
# => { false_beliefs: [{ domain: :weather, content: 'sunny' }], count: 1 }

# Take their perspective
client.perspective_take(agent_id: 'agent_bob')
# => { spatial: 0.5, temporal: 0.5, epistemic: 0.7, emotional: 0.5, motivational: 0.8 }

# Compare two agents
client.compare_agents(agent_id_a: 'agent_bob', agent_id_b: 'agent_alice')
# => { shared_beliefs: [...], conflicting_goals: [...], interaction_gap: 0.3 }

# Per-tick update (reads social + mesh observations from tick_results)
client.update_theory_of_mind(tick_results: tick_output)
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT

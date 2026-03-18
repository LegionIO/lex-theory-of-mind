# lex-theory-of-mind

**Level 3 Leaf Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Gem**: `lex-theory-of-mind`
- **Version**: `0.1.1`
- **Namespace**: `Legion::Extensions::TheoryOfMind`

## Purpose

Implements Theory of Mind (ToM) — the agent's model of other agents' mental states. For each observed agent, tracks their believed beliefs, desires, and intentions (BDI). Supports false-belief detection (agent holds a belief the observer knows to be incorrect), behavior prediction, perspective taking across five dimensions, and prediction accuracy tracking via EMA. Enables the agent to reason about what others know, want, and plan to do.

## Gem Info

- **Gem name**: `lex-theory-of-mind`
- **License**: MIT
- **Ruby**: >= 3.4
- **No runtime dependencies** beyond the Legion framework

## File Structure

```
lib/legion/extensions/theory_of_mind/
  version.rb                           # VERSION = '0.1.0'
  helpers/
    constants.rb                       # limits, decay rate, alpha, stale threshold, BDI enums, prediction outcomes
    agent_model.rb                     # AgentModel class — BDI model for a single observed agent
    mental_state_tracker.rb            # MentalStateTracker class — indexed store of AgentModels
  runners/
    theory_of_mind.rb                  # Runners::TheoryOfMind module — all public runner methods
  client.rb                            # Client class including Runners::TheoryOfMind
```

## Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `MAX_AGENT_MODELS` | 100 | Maximum tracked agents |
| `MAX_BELIEFS_PER_AGENT` | 50 | Maximum belief records per agent |
| `MAX_DESIRES_PER_AGENT` | 20 | Maximum desire records per agent |
| `MAX_INTENTIONS_PER_AGENT` | 10 | Maximum intention records per agent |
| `BELIEF_DECAY_RATE` | 0.01 | Per-tick confidence decrease on beliefs |
| `CONFIDENCE_THRESHOLD` | 0.3 | Beliefs below this are removed during decay |
| `PREDICTION_ALPHA` | 0.15 | EMA alpha for prediction accuracy updates |
| `STALE_BELIEF_THRESHOLD` | 3600 | Seconds before a belief is considered stale |
| `PERSPECTIVE_DIMENSIONS` | 5 symbols | `:spatial`, `:temporal`, `:epistemic`, `:emotional`, `:motivational` |
| `BELIEF_SOURCES` | 5 symbols | `:direct_observation`, `:inference`, `:communication`, `:assumption`, `:memory` |
| `INTENTION_CONFIDENCE_LEVELS` | array | Confidence tier labels for intentions |
| `DESIRE_PRIORITIES` | array | Priority labels: low, medium, high, critical |
| `PREDICTION_OUTCOMES` | 4 symbols | `:correct`, `:incorrect`, `:partial`, `:unknown` |

## Helpers

### `Helpers::AgentModel`

BDI model for a single observed agent.

- `initialize(id:, agent_name:, domain: :general)` — beliefs hash, desires hash, intentions hash, prediction_log array, prediction_accuracy=0.5
- `update_belief(domain:, content:, confidence:, source: :observation)` — upserts belief record; rejects invalid sources; enforces MAX_BELIEFS_PER_AGENT (removes lowest-confidence belief on overflow); timestamps belief
- `update_desire(goal:, priority: :medium)` — upserts desire record; enforces MAX_DESIRES_PER_AGENT
- `update_intention(action:, confidence: 0.5)` — upserts intention record; enforces MAX_INTENTIONS_PER_AGENT
- `belief_for(domain)` — returns current belief for domain; nil if absent
- `strongest_desire` — desire with highest priority and confidence
- `most_likely_intention` — intention with highest confidence
- `false_beliefs(known_truths)` — beliefs where confidence < 0.5 and content contradicts a known_truth value (comparison by content string mismatch)
- `update_prediction_accuracy(outcome)` — EMA on accuracy: correct=1.0, partial=0.5, incorrect=0.0; PREDICTION_ALPHA=0.15
- `decay_beliefs` — decrements confidence on all beliefs by BELIEF_DECAY_RATE; removes below CONFIDENCE_THRESHOLD
- `perspective(dimensions: PERSPECTIVE_DIMENSIONS)` — returns hash of dimension scores inferred from beliefs/desires/intentions

### `Helpers::MentalStateTracker`

Indexed store of AgentModel objects.

- `initialize` — agents hash keyed by agent_id
- `model_for(agent_id:, agent_name: nil, domain: :general)` — creates AgentModel on demand if not found; returns existing if present
- `update_belief(agent_id:, domain:, content:, confidence:, source: :observation)` — delegates to `model.update_belief`
- `update_desire(agent_id:, goal:, priority: :medium)` — delegates
- `infer_intention(agent_id:, action:, confidence: 0.5)` — delegates to `model.update_intention`
- `predict_behavior(agent_id:)` — returns `model.most_likely_intention`; logs to `model.prediction_log`
- `record_prediction_outcome(agent_id:, outcome:)` — calls `model.update_prediction_accuracy`
- `false_belief_check(agent_id:, known_truths:)` — calls `model.false_beliefs`
- `perspective_take(agent_id:)` — calls `model.perspective`
- `compare_agents(agent_id_a:, agent_id_b:)` — returns `{ shared_beliefs:, conflicting_goals:, interaction_gap: }` comparing the two models
- `decay_all` — calls `decay_beliefs` on all models; removes models with no beliefs/desires/intentions remaining
- `agents_tracked` — count of AgentModel instances
- `avg_prediction_accuracy` — mean prediction_accuracy across all models

## Runners

All runners are in `Runners::TheoryOfMind`. The `Client` includes this module and owns a `MentalStateTracker` instance.

| Runner | Parameters | Returns |
|---|---|---|
| `update_theory_of_mind` | `tick_results: {}` | `{ success:, agents_tracked: }` — extracts social+mesh observations from tick_results, calls `decay_all` |
| `observe_agent` | `agent_id:, agent_name: nil, observations: {}` | `{ success:, agent_id:, beliefs_updated:, desires_updated:, intentions_updated: }` |
| `predict_behavior` | `agent_id:` | `{ success:, agent_id:, predicted_action:, confidence: }` |
| `record_outcome` | `agent_id:, outcome:` | `{ success:, agent_id:, prediction_accuracy: }` |
| `check_false_beliefs` | `agent_id:, known_truths: {}` | `{ success:, agent_id:, false_beliefs:, count: }` |
| `perspective_take` | `agent_id:` | `{ success:, agent_id:, perspective: }` |
| `compare_agents` | `agent_id_a:, agent_id_b:` | `{ success:, shared_beliefs:, conflicting_goals:, interaction_gap: }` |
| `mental_state` | `agent_id:` | `{ success:, agent_id:, beliefs:, desires:, intentions:, prediction_accuracy: }` |
| `tom_stats` | (none) | Agents tracked, avg prediction accuracy, total beliefs/desires/intentions |

### `update_theory_of_mind` Tick Integration

Reads from `tick_results`:
- `tick_results.dig(:social_interface, :observations)` — array of `{ agent_id:, beliefs:, desires:, intentions: }` hashes
- `tick_results.dig(:mesh_interface, :messages)` — mesh messages attributed to sender agents, used to infer intentions
After processing, calls `decay_all` to age all beliefs.

## Integration Points

- **lex-tick / lex-cortex**: `update_theory_of_mind` wired as a tick phase handler; reads social and mesh observation data automatically
- **lex-social**: social group membership and reputation tracks who the agent interacts with; ToM builds mental models for those same agents
- **lex-mesh**: mesh messages are attributed to their sender agents; inferred intentions can be added via `infer_intention` from mesh traffic
- **lex-identity**: the agent's own behavioral fingerprint (lex-identity) is the self-model; ToM models external agents
- **lex-trust**: trust scores from lex-trust influence how much confidence to assign incoming beliefs — high-trust source = higher confidence

## Development Notes

- BDI records are plain hashes stored in the AgentModel; no separate class for individual beliefs/desires/intentions
- `false_beliefs` checks content mismatch against known_truths — this is a simple string comparison, not semantic reasoning; callers supply the known_truths hash
- `perspective` infers dimension scores from the current BDI state: epistemic from belief count/confidence, motivational from desire priorities, emotional from emotional beliefs — this is heuristic, not a direct measurement
- `decay_all` removes empty models (no beliefs/desires/intentions remaining) to keep the tracker lean
- `STALE_BELIEF_THRESHOLD = 3600` is enforced in `decay_beliefs` — beliefs with `updated_at` older than the threshold are removed regardless of confidence

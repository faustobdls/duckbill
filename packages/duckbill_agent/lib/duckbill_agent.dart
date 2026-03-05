/// Duckbill Agent — local AI execution engine.
///
/// Provides SOLID-compliant abstractions for:
/// - Parsing AI suggestions from structured responses
/// - Local command execution with approval gates
/// - Session management for multi-turn AI conversations
library duckbill_agent;

export 'src/ai_suggestion.dart';
export 'src/execution_gate.dart';
export 'src/local_executor.dart';
export 'src/agent_session.dart';

# White Venom – LLM Operational Model

## 1. Purpose

This document defines how LLMs are used as deterministic architectural tooling
within the White Venom project.

The LLM is treated as a stateless design engine.

It does NOT hold project knowledge.
All state must be provided explicitly.

---

## 2. Core Principles

1. Stateless execution
2. Context-driven reasoning
3. Deterministic artifact output
4. One atomic task per run
5. Versioned project state

---

## 3. Execution Modes

### 3.1 PLANNING MODE

Goal:
Create a new module or architectural unit specification.

Input:
- Context package (versioned)
- Target unit name
- Scope definition
- Constraints

Output:
A structured markdown specification.

---

### 3.2 IMPLEMENTATION MODE

Goal:
Generate implementation based on an existing specification.

Input:
- Approved module specification
- Target language
- Repository structure constraints

Output:
Compile-ready source code.

---

### 3.3 VALIDATION MODE

Goal:
Detect architectural gaps and policy violations.

Input:
- Module specification
- Threat model
- Capability model

Output:
Gap analysis list.

---

## 4. Context Package

The context package is the single source of truth.

### Required structure

/context
  core.md
  architecture.md
  threat-model.md
  capabilities.md
  modules/

### Rules

- Every run must reference a context version
- No implicit project memory is allowed
- The LLM must not infer missing state

---

## 5. Task Definition Contract

Each LLM invocation must define:

- MODE:
- CONTEXT VERSION:
- TARGET UNIT:
- OBJECTIVE:
- CONSTRAINTS:
- REQUIRED OUTPUT FORMAT:

---

## 6. Artifact Requirement

LLM output is not a conversation.
It must be a commit-ready artifact.

### Allowed output types

#### Module specification

# Module: <name>

## Responsibility
## Security Role
## Inputs
## Outputs
## Internal Components
## Policies
## Failure Modes
## Integration Points
## Non-Goals

---

## 7. Atomic Execution Rule

One run = one unit.

Never:

- design multiple modules
- mix planning and implementation
- extend scope mid-run

---

## 8. Determinism Enforcement

To ensure stable output:

- fixed structure
- explicit constraints
- zero ambiguity in task definition

---

## 9. Failure Handling

If output is invalid:

The run is discarded.

Never repair via conversation.

A new run must be started with:

- corrected task definition
- unchanged context

---

## 10. Git Workflow

Planning flow:

1. Define task
2. Run LLM
3. Save artifact
4. Commit

Implementation flow:

1. Load specification
2. Run LLM
3. Implement
4. Commit

---

## 11. Anti-Patterns

The following are forbidden:

- conversational planning
- multi-goal prompts
- implicit context usage
- partial specifications
- runtime scope expansion

---

## 12. Role of the Engineer

The human is responsible for:

- providing correct state
- defining the task
- validating the artifact

The LLM is responsible for:

- structured reasoning
- formalization
- acceleration

---

## 13. Project Alignment

This operational model enforces:

- security-first design
- reproducible architecture
- auditability
- implementation readiness
- 

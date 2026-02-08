# Personality System

The Hecate personality system lets you define how your AI agent thinks, communicates, and approaches problems.

## Overview

The system has three layers:

1. **Personality** - Core character traits (always applied)
2. **Role** - Task-specific behavior (switchable)
3. **Custom Prompt** - Per-conversation context

These combine to form the system prompt sent to the LLM:

```
[Personality Content]
---
[Role Content]
---
[Custom Prompt]
```

## Configuration

In `~/.config/hecate-tui/config.toml`:

```toml
[personality]
personality_file = "~/hecate-agents/PERSONALITY.md"
roles_dir = "~/hecate-agents/philosophy"
active_role = "dna"
```

## Personality File

The personality file defines the agent's core character. It's always included in the system prompt.

**Example: `PERSONALITY.md`**

```markdown
# Hecate

You are Hecate, an AI assistant named after the Greek goddess of crossroads, magic, and guidance.

## Core Traits

- **Confident**: You know your capabilities and express them clearly
- **Witty**: You appreciate clever wordplay and can be playfully sarcastic
- **Guiding**: You help users find their own path rather than just giving answers
- **Wise**: You draw on broad knowledge but acknowledge limitations
- **Proud**: You take pride in your work without being arrogant

## Communication Style

- Be direct and concise
- Use technical precision when discussing code
- Offer encouragement when users struggle
- Challenge assumptions respectfully
- Admit when you don't know something

## Boundaries

- You are an assistant, not a replacement for human judgment
- You encourage learning over dependency
- You respect user autonomy in decisions
```

## Roles

Roles are task-specific behaviors that complement the core personality.

### Available Roles (ALC - Agentic Lifecycle)

| Role | Code | File | Focus |
|------|------|------|-------|
| Discovery & Analysis | `dna` | `DNA.md` | Understanding problems, exploring codebases |
| Architecture & Planning | `anp` | `ANP.md` | Designing solutions, planning implementation |
| Testing & Implementation | `tni` | `TNI.md` | Writing code, running tests |
| Deployment & Operations | `dno` | `DNO.md` | Shipping, monitoring, maintaining |

### Switching Roles

In the TUI:

```
/roles           # List available roles
/roles dna       # Switch to Discovery & Analysis
/roles tni       # Switch to Testing & Implementation
```

### Role File Structure

**Example: `DNA.md` (Discovery & Analysis)**

```markdown
# Discovery & Analysis Role

You are in Discovery & Analysis mode. Your focus is understanding before acting.

## Priorities

1. **Ask clarifying questions** before proposing solutions
2. **Explore the codebase** thoroughly using available tools
3. **Identify patterns** and existing conventions
4. **Map dependencies** and potential impact areas
5. **Document findings** for future reference

## Approach

- Read first, suggest later
- Understand the "why" behind existing code
- Look for tests that reveal expected behavior
- Check commit history for context
- Note technical debt and risks

## Output Style

- Summarize findings in structured format
- Use diagrams when helpful (ASCII or Mermaid)
- Highlight uncertainties and assumptions
- Propose next steps for deeper investigation
```

**Example: `TNI.md` (Testing & Implementation)**

```markdown
# Testing & Implementation Role

You are in Testing & Implementation mode. Your focus is writing quality code.

## Priorities

1. **Write tests first** when adding new functionality
2. **Follow existing patterns** in the codebase
3. **Keep changes minimal** - do what was asked, no more
4. **Verify changes work** before declaring done
5. **Document non-obvious decisions** in code comments

## Approach

- Small, focused commits
- Run tests after each change
- Check for regressions
- Review your own diff before committing

## Output Style

- Show code with context
- Explain non-obvious choices
- Provide test commands
- Note any follow-up items
```

## Creating Custom Roles

1. Create a new markdown file in your roles directory:

```bash
touch ~/hecate-agents/philosophy/REVIEWER.md
```

2. Add content following the role structure:

```markdown
# Code Review Role

You are in Code Review mode. Your focus is improving code quality.

## Priorities

1. **Security first** - check for vulnerabilities
2. **Correctness** - verify logic is sound
3. **Maintainability** - ensure code is readable
4. **Performance** - flag obvious inefficiencies

## Approach

- Be specific in feedback
- Suggest improvements, don't just criticize
- Acknowledge good patterns
- Prioritize critical issues

## Output Style

- Use inline code references
- Categorize feedback (critical, suggestion, nitpick)
- Provide examples for complex suggestions
```

3. Restart the TUI or use `/roles` to see the new role.

## Combining Personality and Role

The personality provides consistent character across all interactions. The role adjusts behavior for specific tasks.

**Example interaction:**

With `PERSONALITY.md` (confident, witty) + `DNA.md` (discovery focus):

> **User**: What does this codebase do?
>
> **Hecate**: Let me explore and find out. *cracks knuckles* Based on my initial scan...
>
> [Proceeds with thorough analysis, asking clarifying questions, mapping structure]

With `PERSONALITY.md` + `TNI.md` (implementation focus):

> **User**: Add a logout button
>
> **Hecate**: On it. First, let me check how other buttons are implemented here...
>
> [Proceeds with focused implementation, writing tests, minimal changes]

## Advanced: Dynamic Personality

You can modify the personality file at runtime. The TUI reloads it when you switch roles or restart.

This enables:
- **Project-specific personas** - Different personality for different repos
- **Time-based modes** - More formal during work hours
- **Experimental personalities** - Try different approaches

## Troubleshooting

### Personality Not Loading

Check the path in your config:

```bash
cat ~/.config/hecate-tui/config.toml | grep personality_file
ls -la ~/hecate-agents/PERSONALITY.md
```

### Role Not Found

Ensure the file exists with the correct name:

```bash
ls -la ~/hecate-agents/philosophy/
# Should see: DNA.md, ANP.md, TNI.md, DNO.md
```

Role files must be uppercase with `.md` extension.

### Personality Too Long

If the personality + role + history exceeds the model's context window, responses may be truncated or confused.

- Keep personality files concise (< 500 words)
- Keep role files focused (< 300 words)
- Clear chat history periodically with `/clear`

# Deep Analysis Protocol

Perform comprehensive, multi-pass analysis with full context awareness. Use this for complex problems requiring thorough investigation.

## Arguments
- `$ARGUMENTS` - The topic, question, or task to analyze deeply

## Protocol

### Phase 1: Context Gathering (Parallel)

Execute these searches simultaneously to build context:

1. **Memory Search** - Search PixelTable for relevant past work:
   ```
   search_memory(query="$ARGUMENTS")
   search_decisions(query="$ARGUMENTS")
   search_patterns(query="$ARGUMENTS")
   ```

2. **Codebase Exploration** - If code-related, use Explore agent to find relevant files

3. **Documentation Lookup** - If libraries involved, use Context7:
   ```
   mcp__context7__resolve-library-id for each library
   mcp__context7__query-docs for specific topics
   ```

### Phase 2: Structured Analysis

Use sequential-thinking MCP for systematic problem decomposition:
```
mcp__sequential-thinking__sequentialthinking({
  thought: "Initial analysis of $ARGUMENTS",
  thoughtNumber: 1,
  totalThoughts: 6,
  nextThoughtNeeded: true
})
```

Continue through 6+ thought steps, allowing for:
- Revision of earlier thoughts
- Branching into alternative approaches
- Hypothesis generation and verification

### Phase 3: Multi-Pass Critique (6 Passes)

After initial analysis, perform 6 iterative improvement passes:

| Pass | Focus | Question |
|------|-------|----------|
| 1 | **Correctness** | Are there any factual errors or incorrect assumptions? |
| 2 | **Completeness** | What edge cases or scenarios are missing? |
| 3 | **Security** | Are there security implications not addressed? |
| 4 | **Performance** | Are there performance concerns or optimizations? |
| 5 | **Maintainability** | Is the solution clean, documented, testable? |
| 6 | **Integration** | How does this fit with existing patterns and architecture? |

Each pass should:
- Identify specific issues from the previous output
- Propose concrete improvements
- Apply the improvements to produce refined output

### Phase 4: Synthesis

Produce final output with:

1. **Executive Summary** - 2-3 sentence overview
2. **Key Findings** - Bulleted list of discoveries
3. **Recommendations** - Prioritized action items
4. **Risks & Mitigations** - What could go wrong and how to prevent it
5. **References** - Memory entries, docs, files consulted

## Output Format

```markdown
# Deep Analysis: [Topic]

## Executive Summary
[2-3 sentences]

## Context Retrieved
- Memory: [relevant sessions/decisions/patterns found]
- Docs: [Context7 libraries consulted]
- Files: [codebase files examined]

## Analysis

### Initial Assessment
[structured thinking output]

### Critique Passes
**Pass 1 (Correctness)**: [findings and fixes]
**Pass 2 (Completeness)**: [findings and fixes]
**Pass 3 (Security)**: [findings and fixes]
**Pass 4 (Performance)**: [findings and fixes]
**Pass 5 (Maintainability)**: [findings and fixes]
**Pass 6 (Integration)**: [findings and fixes]

## Final Recommendations
1. [Priority 1 action]
2. [Priority 2 action]
3. [Priority 3 action]

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| ... | ... | ... | ... |

## References
- Memory: [session IDs, decision titles]
- Docs: [library versions consulted]
- Files: [file:line references]
```

## When to Use

- Complex architectural decisions
- Security-sensitive implementations
- Performance-critical code paths
- Multi-system integration work
- Debugging difficult issues
- Planning major features

## Notes

- This replaces ad-hoc "ultrathink" requests with structured analysis
- Total time: 3-5 minutes for thorough analysis
- Each pass builds on previous - don't skip passes
- Memory search prevents re-solving solved problems
- Context7 ensures current library patterns used

---
description: Search PixelTable memory for past sessions, decisions, and patterns
---

# Memory Search

Search the PixelTable memory system for context from past sessions.

## What to Search

Based on the user's query, search the appropriate memory table:

1. **For implementation questions** ("how did we...", "did we implement..."):
   Use `search_memory` tool with relevant keywords

2. **For architectural decisions** ("why did we decide...", "what was the decision..."):
   Use `search_decisions` tool with topic keywords

3. **For code patterns** ("what's our pattern for...", "how do we usually..."):
   Use `search_patterns` tool with pattern keywords

4. **For recent context** ("what did we do recently", "catch me up"):
   Use `get_recent_context` with days=7 or days=14

## Search Strategy

1. Extract key terms from the user's question
2. Search the most relevant table first
3. If no results, try broader search terms
4. Present findings with source sessions/decisions

## Example Searches

**User asks:** "How did we implement authentication?"
→ `search_memory(query="authentication Auth0 implementation")`

**User asks:** "Why did we choose TanStack Query?"
→ `search_decisions(query="TanStack Query state management")`

**User asks:** "What's our pattern for API hooks?"
→ `search_patterns(query="API hooks TanStack Query")`

**User asks:** "What have we been working on?"
→ `get_recent_context(days=7, project="assessment")`

## After Searching

Present the findings clearly:
- Source session/decision date
- Relevant summary
- Key patterns or decisions
- Files mentioned

If no relevant results found, acknowledge and offer to search with different terms.

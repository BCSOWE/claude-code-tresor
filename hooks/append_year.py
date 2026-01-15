#!/usr/bin/env python3
"""Append current year to web search queries.

This PreToolUse hook intercepts WebSearch tool calls and appends the current
year to queries that don't already contain it. This helps ensure search
results prioritize recent content over outdated articles.

Example:
    Input:  "React hooks best practices"
    Output: "React hooks best practices 2026"
"""

import json
import sys
from datetime import datetime


def main():
    try:
        # Read tool input from stdin
        data = json.load(sys.stdin)

        # Only modify if there's a query field
        if 'query' in data and isinstance(data['query'], str):
            year = str(datetime.now().year)
            query = data['query']

            # Don't append if year is already in the query
            if year not in query:
                data['query'] = f"{query} {year}"

        # Output modified input (must be valid JSON)
        json.dump(data, sys.stdout)

    except json.JSONDecodeError:
        # If input isn't valid JSON, pass through unchanged
        sys.exit(0)
    except Exception:
        # Graceful degradation - don't break the tool call
        sys.exit(0)


if __name__ == "__main__":
    main()

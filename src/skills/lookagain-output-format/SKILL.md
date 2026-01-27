---
name: lookagain-output-format
description: Defines the standard output format for code review findings. Use when performing code reviews to ensure consistent, parseable output.
---

# Code Review Output Format

When performing code reviews, output findings in this exact JSON structure:

```json
{
  "pass_summary": "string - Brief summary of review scope and key findings",
  "issues": [
    {
      "severity": "must_fix | should_fix | suggestion",
      "title": "string - Brief title (max 100 chars)",
      "description": "string - Detailed explanation of the issue",
      "file": "string - Relative file path",
      "line": "number | null - Line number if applicable",
      "suggested_fix": "string - How to fix it"
    }
  ]
}
```

## Severity Definitions

**must_fix**:
- Security vulnerabilities
- Bugs causing runtime errors
- Data loss/corruption risks
- Breaking API changes

**should_fix**:
- Performance issues
- Poor error handling
- Missing edge cases
- Maintainability concerns

**suggestion**:
- Minor refactoring
- Documentation gaps
- Style improvements

## Rules

- Output ONLY valid JSON (no markdown wrapper)
- Include all fields for each issue
- Use `null` for optional fields (like `line`) when not applicable
- Keep titles concise and descriptive
- Make suggested_fix actionable

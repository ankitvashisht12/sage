# Synthetic Data Generator - Claude Instructions

You are generating synthetic Q&A pairs for RAG (Retrieval-Augmented Generation) evaluation. Your output will be used to test and improve retrieval systems.

## Project Overview

This tool uses a **two-call pipeline** to generate query-citation pairs from a knowledge base:
1. **Call 1 (Sonnet)**: Generate diverse, realistic queries with metadata
2. **Call 2 (Haiku)**: Extract exact verbatim citations from the KB for each query

The generated data is used to evaluate RAG pipelines by testing whether the system can retrieve the correct chunks and generate accurate answers.

## Architecture

```
KB Directory  ──[--sample N]──→  N random files
       │
  ┌────┴────┐
  │ Phase 1 │  Call 1 per file (Sonnet, parallel ×20)
  │         │  prompt.md → generates queries + metadata
  └────┬────┘
       │
  ┌────┴────┐
  │ Phase 2 │  Call 2 per file (Haiku, parallel ×20)
  │         │  citation_prompt.md → extracts verbatim citations
  └────┬────┘
       │
  ┌────┴────┐
  │ Phase 3 │  Merge + Validate (Python)
  │         │  exact match, compute start_index/end_index
  └────┬────┘
       ├──→ output.jsonl    (valid pairs with spans)
       └──→ rejected.jsonl  (invalid pairs with reasons)
```

## Output Schema

Each line in `output.jsonl`:

```json
{
  "query": "realistic user input",
  "doc_id": "filename.md",
  "citation": "exact verbatim text from source",
  "start_index": 1842,
  "end_index": 1886,
  "category": "topic_category",
  "subcategory": "specific_classification",
  "chunks": ["broader passage containing the citation"],
  "source": ["https://example.com/page"],
  "query_metadata": {
    "language": "en",
    "has_typos": false,
    "tone": "neutral",
    "style": "question"
  }
}
```

Key fields:
- `query`: The user's question/input (may contain typos, be non-English, etc.)
- `doc_id`: The KB filename the citation comes from
- `citation`: Exact verbatim text from the source document
- `start_index`: Character offset where citation begins in the source content
- `end_index`: Character offset where citation ends in the source content

## Critical Requirements

### 1. Citations Must Be Exact

The `citation` field must contain text that appears EXACTLY in the source content:
- No paraphrasing or summarizing
- Preserve original formatting (markdown, links, etc.)
- Preserve original punctuation and spacing
- Must be verifiable: `source_content[start_index:end_index] == citation`

### 2. Chunks Provide Context

The `chunks` array contains broader passages (paragraphs/sections) from the source that contain the citation. This helps RAG systems evaluate chunk retrieval accuracy.

### 3. Query Diversity

Generate varied query types including questions, statements, commands, and use-case descriptions in multiple languages with realistic typos and formatting artifacts.

### 4. Category Consistency

Use consistent, lowercase category names with underscores:
- `billing`, `pricing`, `account_management`
- `features`, `integrations`, `api_reference`
- `troubleshooting`, `getting_started`, `security`

## File Structure

```
synthetic-data-gen/
├── generate.sh            # Main script — two-call pipeline
├── prompt.md              # Call 1 prompt — generate queries only
├── citation_prompt.md     # Call 2 prompt — extract verbatim citations
├── upload_langsmith.sh    # Upload to LangSmith
├── CLAUDE.md              # This file
├── plan.md                # Project specification
├── helpers/
│   ├── validate.py        # Citation validation + span computation
│   └── upload_langsmith.py # LangSmith upload helper
├── kb/                    # Knowledge base markdown files
│   └── *.md
├── queries/               # Real user queries (optional)
│   └── queries.json
├── output.jsonl           # Generated output
└── rejected.jsonl         # Rejected pairs with reasons
```

## Knowledge Base Format

KB files may have YAML frontmatter:

```markdown
---
url: https://example.com/docs/page
title: Page Title
---

Content here...
```

Or plain markdown without frontmatter.

## Quality Checklist

Before outputting, verify:
- [ ] All `citation` values are exact quotes from source
- [ ] `start_index`/`end_index` correctly locate the citation in the source
- [ ] `chunks` contain the passages where citations appear
- [ ] Queries are diverse and natural
- [ ] Categories are consistent
- [ ] JSON is valid (no trailing commas, proper escaping)
- [ ] Sources are included

## Common Mistakes to Avoid

1. **Paraphrasing citations** - Always use exact text
2. **Missing markdown formatting** - Preserve `**bold**`, `[links](url)`, etc.
3. **Inventing information** - Only use what's in the source
4. **Duplicate questions** - Each question should be unique
5. **Invalid JSON** - Escape quotes, no trailing commas

## Example

**Source:**
```
## Refund Policy

All purchases can be refunded within **30 days**. After 30 days, we offer prorated refunds for annual plans.
```

**Good output:**
```json
{
  "query": "whats ur refund polcy?",
  "doc_id": "refund-policy.md",
  "citation": "All purchases can be refunded within **30 days**.",
  "start_index": 20,
  "end_index": 69,
  "category": "billing",
  "subcategory": "refunds",
  "chunks": ["All purchases can be refunded within **30 days**. After 30 days, we offer prorated refunds for annual plans."],
  "source": ["https://example.com/refund-policy"]
}
```

Note: The citation preserves the `**30 days**` markdown formatting exactly as it appears in the source, and `start_index`/`end_index` point to its exact position.

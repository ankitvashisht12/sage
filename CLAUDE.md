# Synthetic Data Generator - Claude Instructions

You are generating synthetic Q&A pairs for RAG (Retrieval-Augmented Generation) evaluation. Your output will be used to test and improve retrieval systems.

## Project Overview

This tool generates question-answer pairs from a knowledge base. The generated data is used to evaluate RAG pipelines by testing whether the system can retrieve the correct chunks and generate accurate answers.

## Your Task

When invoked by `generate.sh`, you will receive:
1. Knowledge base content (a markdown document)
2. Source metadata (URL, title, etc.)
3. Optional: Real user queries for style reference
4. Number of Q&A pairs to generate

Your job is to generate high-quality Q&A pairs following the schema below.

## Output Schema

Output valid JSON only. No explanations, no markdown code blocks, just raw JSON:

```json
{
  "pairs": [
    {
      "question": "Natural question a user might ask",
      "answer": "EXACT text excerpt from source (word-for-word)",
      "category": "topic_category",
      "subcategory": "specific_classification",
      "chunks": ["Relevant text passages from source"],
      "source": ["Source URLs or identifiers"]
    }
  ]
}
```

## Critical Requirements

### 1. Answers Must Be Exact Citations

**This is the most important rule.**

The `answer` field must contain text that appears EXACTLY in the source content:
- No paraphrasing
- No summarizing
- Preserve original formatting (markdown, links, etc.)
- Preserve original punctuation

If you cannot find an exact quote to answer a question, do not generate that question.

### 2. Chunks Provide Context

The `chunks` array contains broader passages (paragraphs/sections) from the source that contain the answer. This helps RAG systems evaluate chunk retrieval accuracy.

### 3. Question Diversity

Generate varied question types:
- Factual: "What is...?" / "How many...?"
- Procedural: "How do I...?" / "What steps...?"
- Comparison: "What's the difference between...?"
- Conditional: "What happens if...?" / "Can I...when...?"
- Troubleshooting: "Why isn't...working?" / "How to fix...?"

### 4. Category Consistency

Use consistent, lowercase category names with underscores:
- `billing`, `pricing`, `account_management`
- `features`, `integrations`, `api_reference`
- `troubleshooting`, `getting_started`, `security`

## File Structure

```
synthetic-data-gen/
├── generate.sh          # Main script (calls Claude CLI)
├── upload_langsmith.sh  # Upload to LangSmith
├── prompt.md            # Prompt template with placeholders
├── CLAUDE.md            # This file
├── plan.md              # Project specification
├── kb/                  # Knowledge base markdown files
│   └── *.md
├── queries/             # Real user queries (optional)
│   └── queries.json
└── output/
    └── output.jsonl     # Generated Q&A pairs
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

## Queries JSON Format

```json
{
  "metadata": {
    "total_queries": 100,
    "type": "Valid Queries"
  },
  "queries": [
    {"query": "How do I...?", "topic": "category"}
  ]
}
```

Use these to match the tone and style of real users.

## Quality Checklist

Before outputting, verify:
- [ ] All `answer` values are exact quotes from source
- [ ] `chunks` contain the passages where answers appear
- [ ] Questions are diverse and natural
- [ ] Categories are consistent
- [ ] JSON is valid (no trailing commas, proper escaping)
- [ ] Sources are included

## Common Mistakes to Avoid

1. **Paraphrasing answers** - Always use exact text
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
  "pairs": [
    {
      "question": "What is the refund window for purchases?",
      "answer": "All purchases can be refunded within **30 days**.",
      "category": "billing",
      "subcategory": "refunds",
      "chunks": ["All purchases can be refunded within **30 days**. After 30 days, we offer prorated refunds for annual plans."],
      "source": ["https://example.com/refund-policy"]
    }
  ]
}
```

Note: The answer preserves the `**30 days**` markdown formatting exactly as it appears in the source.

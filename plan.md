# Synthetic Data Generation Tool

A CLI tool for generating synthetic Q&A data from a knowledge base using Claude Code, designed for RAG pipeline evaluation.

## Inspiration

Inspired by the [Ralph](https://github.com/snarktank/ralph) pattern - using bash scripts to orchestrate Claude CLI for iterative tasks. Ralph uses `claude --dangerously-skip-permissions --print < prompt.md` to run autonomous AI loops. We adapt this approach for synthetic data generation.

---

## Core Components

### 1. Bash Scripts

#### `generate.sh` - Main Generation Script
- Accepts path to knowledge base directory
- Accepts path to prompt template
- Optionally accepts path to real user queries file
- Iterates through each markdown file in KB
- Calls Claude CLI for each file to generate Q&A pairs
- Outputs results to `output.jsonl`

#### `upload_langsmith.sh` - LangSmith Upload (Optional)
- Reads generated `output.jsonl`
- Uploads dataset to LangSmith for RAG evaluation
- Requires LangSmith API key configuration

---

### 2. Input Files

#### Knowledge Base (`kb/`)
A directory containing markdown files. Each file can have two formats:

**Format A: With YAML Frontmatter**
```markdown
---
url: https://example.com/docs/page
title: Page Title
author: John Doe
---

# Content Heading

Actual content goes here...
```

**Format B: Plain Markdown**
```markdown
# Content Heading

Just content, no metadata...
```

#### Prompt Template (`prompt.md`)
The prompt passed to Claude CLI. Should instruct Claude to:
- Read the provided KB content
- Generate diverse synthetic questions
- Provide answers that are word-for-word excerpts from the source (citations)
- Extract relevant chunks from the source document
- Categorize questions appropriately

Example structure:
```markdown
You are a synthetic data generator for RAG evaluation.

Given the following knowledge base content, generate Q&A pairs.

## Knowledge Base Content
{{KB_CONTENT}}

## Real User Queries (for style reference)
{{USER_QUERIES}}

## Output Format
Generate JSON with: question, answer, category, chunks, subcategory, source

...detailed instructions...
```

#### Real User Queries (`queries.json`) - Optional
Sample real queries to guide the LLM toward generating similar style questions.

```json
{
  "metadata": {
    "total_queries": 287,
    "source_file": "/path/to/source",
    "verified": true,
    "type": "Valid Queries"
  },
  "queries": [
    {
      "query": "How do I reset my password?",
      "topic": "account_management"
    },
    {
      "query": "What are the pricing tiers?",
      "topic": "billing"
    },
    {
      "query": "Can I export my data?",
      "topic": "data_export"
    }
  ]
}
```

The `topic` field can be used to filter queries relevant to the current KB page being processed.

---

### 3. Output Format

**File:** `output.jsonl` (JSON Lines format)

Each line is a JSON object:
```json
{
  "question": "What is the refund policy for annual subscriptions?",
  "answer": "Annual subscriptions can be refunded within 30 days of purchase. After 30 days, refunds are prorated based on remaining months.",
  "category": "Billing",
  "subcategory": "Refunds",
  "chunks": [
    "Our refund policy ensures customer satisfaction. Annual subscriptions can be refunded within 30 days of purchase. After 30 days, refunds are prorated based on remaining months. Monthly subscriptions are non-refundable.",
    "For enterprise plans, contact support for custom refund arrangements."
  ],
  "source": [
    "https://example.com/docs/billing/refunds"
  ]
}
```

**Schema:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| question | string | Yes | The synthetic question |
| answer | string | Yes | Word-for-word excerpt/citation from the source that answers the question |
| category | string | Yes | Topic/category |
| subcategory | string | No | More specific classification |
| chunks | string[] | Yes | Relevant text passages from the source document |
| source | string[] | Yes | URLs/references (from frontmatter or filename) |

---

## Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| Q&A pairs per file | Claude decides (max 15) | Claude determines based on content length/depth |
| Answer validation | 95% fuzzy match | Answers must match source text at 95%+ similarity |
| Question duplicate detection | 95% fuzzy match | Questions with 95%+ similarity are duplicates |
| Retry logic | Skip and log | Failed files are skipped, errors logged |
| Resume capability | Yes | Tracks progress in `.generation_state.json` |
| Output path | `./output.jsonl` | Same directory as script |
| Failed validations | `./rejected.jsonl` | Rejected pairs logged separately |

---

## Interactive Flow

```
$ ./generate.sh

Synthetic Data Generator
========================

Enter path to knowledge base (KB) directory: ./kb
Enter path to queries.json (optional, press Enter to skip): ./queries/queries.json

Found 15 markdown files in ./kb

Starting generation...

[1/15] pricing.md ████████████████████ 100%
       Generated: 8 questions | Validated: 8 | Rejected: 0

[2/15] getting-started.md ████████████████████ 100%
       Generated: 12 questions | Validated: 11 | Rejected: 1

...

Generation complete!
Total: 127 questions | Validated: 124 | Rejected: 3

Output: ./output.jsonl
Rejected: ./rejected.jsonl
```

---

## State File for Resume

When processing is interrupted, progress is saved to `.generation_state.json`:

```json
{
  "kb_path": "./kb",
  "queries_path": "./queries/queries.json",
  "processed_files": [
    "pricing.md",
    "getting-started.md",
    "api-reference.md"
  ],
  "total_questions": 47,
  "last_updated": "2025-02-02T10:30:00Z"
}
```

On restart, script detects existing state and prompts:
```
Found previous session with 3/15 files processed. Resume? [Y/n]
```

---

## Processing Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      generate.sh                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Interactive prompts                                     │
│     - Ask for KB path (required)                            │
│     - Ask for queries.json path (optional)                  │
│     - Check for resume state                                │
│                           │                                 │
│                           ▼                                 │
│  2. Load prompt template from prompt.md                     │
│                           │                                 │
│                           ▼                                 │
│  3. Load real queries (if provided)                         │
│                           │                                 │
│                           ▼                                 │
│  4. For each .md file in kb/:                               │
│     ┌─────────────────────────────────────────┐             │
│     │ a. Skip if already processed (resume)   │             │
│     │ b. Extract frontmatter (if exists)      │             │
│     │ c. Extract content                      │             │
│     │ d. Substitute into prompt template      │             │
│     │ e. Call: claude --print -p "prompt"     │             │
│     │    (fresh context per file)             │             │
│     │ f. Parse JSON response                  │             │
│     │ g. Validate answers (95% fuzzy match)   │             │
│     │ h. Check question uniqueness            │             │
│     │ i. Append valid pairs to output.jsonl   │             │
│     │ j. Log rejected pairs to rejected.jsonl │             │
│     │ k. Update state file                    │             │
│     │ l. Display progress                     │             │
│     └─────────────────────────────────────────┘             │
│                           │                                 │
│                           ▼                                 │
│  5. Output: output.jsonl + rejected.jsonl                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Usage

### Generate Synthetic Data
```bash
./generate.sh
```
The script will interactively prompt for:
1. KB directory path (required)
2. queries.json path (optional)

If a previous session exists, it will offer to resume.

### Upload to LangSmith
```bash
# First, copy example.env to .env and fill in your credentials
cp example.env .env

# Then run the upload script
./upload_langsmith.sh
```
The script will read `output.jsonl` and upload to LangSmith, returning the dataset URL.

### Requirements

- **Claude CLI** - Install from https://claude.ai/download
- **jq** - JSON processor (`brew install jq` on macOS)
- **uv** - Python package manager (auto-installs dependencies)
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

Python dependencies (auto-managed by `uv`):
- `langsmith` - For uploading to LangSmith

---

## File Structure

```
synthetic-data-gen/
├── generate.sh              # Main generation script
├── upload_langsmith.sh      # LangSmith upload script
├── prompt.md                # Prompt template with placeholders
├── CLAUDE.md                # Claude instructions for generation
├── plan.md                  # This file - project specification
├── pyproject.toml           # Python dependencies (managed by uv)
├── example.env              # Environment template for LangSmith
├── .env                     # User's actual credentials (gitignored)
├── .generation_state.json   # Resume state tracking (auto-generated)
├── output.jsonl             # Generated Q&A pairs (auto-generated)
├── rejected.jsonl           # Failed validations (auto-generated)
├── helpers/                 # Python helper scripts
│   ├── validate.py          # Fuzzy matching & deduplication
│   └── upload_langsmith.py  # LangSmith upload logic
├── kb/                      # Example knowledge base
│   ├── page1.md
│   ├── page2.md
│   └── ...
└── queries/                 # Example user queries
    └── queries.json
```

---

## Validation

### Answer Validation
Each generated answer must be validated against the source content:
- Use fuzzy string matching (95% threshold)
- If answer matches source text at ≥95% similarity → **VALID**
- If answer matches source text at <95% similarity → **REJECTED**
- Rejected pairs are logged to `rejected.jsonl` with reason

### Question Uniqueness
Before appending to `output.jsonl`, check for duplicate questions:
- Compare new question against all existing questions in output
- Use fuzzy matching (95% threshold)
- If ≥95% similar to existing question → **DUPLICATE** (rejected)
- Answers CAN be duplicates (same answer, different questions is valid)

### Validation Output
```json
// rejected.jsonl entry
{
  "question": "What is the refund policy?",
  "answer": "Refunds are available within thirty days",
  "rejection_reason": "answer_mismatch",
  "similarity_score": 0.72,
  "source_file": "pricing.md",
  "timestamp": "2025-02-02T10:30:00Z"
}
```

---

## Implementation Notes

### Claude CLI Invocation
Following Ralph's pattern:
```bash
claude --print -p "Your prompt here with KB content embedded"
```

Or using stdin:
```bash
echo "$FULL_PROMPT" | claude --print
```

### Frontmatter Parsing
Use `awk` or `sed` to extract YAML frontmatter between `---` delimiters:
```bash
# Extract frontmatter
awk '/^---$/{p=!p; next} p' file.md

# Extract content (after frontmatter)
awk '/^---$/{p++; next} p>=2' file.md
```

### JSON-L Output
Each Claude response should be validated as JSON before appending:
```bash
echo "$response" | jq -c '.' >> output.jsonl
```

### Error Handling
- Skip files that fail to process
- Log errors to stderr
- Continue with remaining files
- Report summary at end (success/failed counts)

---

## End Goal

1. **Generate** synthetic Q&A data from documentation/knowledge base
2. **Upload** to LangSmith (optional)
3. **Evaluate** RAG pipeline using the synthetic dataset

This creates a feedback loop for improving RAG systems by testing against realistic, domain-specific questions derived from actual knowledge base content.

---

## Decisions Made

| Question | Decision |
|----------|----------|
| Q&A pairs per page | Claude decides based on content (max 15 per page) |
| Progress indicators | Yes - show file progress, percentage, question counts |
| Validation threshold | 95% fuzzy match for both answers and question uniqueness |
| Failed files | Skip and log error, continue with remaining files |
| Resume capability | Yes - track in `.generation_state.json` |
| Duplicate handling | Questions must be unique; answers can repeat |

## Open Questions

1. Should we add a `--dry-run` option to preview without calling Claude?
2. How large should each chunk be? (paragraph-level, section-level?)
3. Should we support filtering queries by topic to match KB page category?

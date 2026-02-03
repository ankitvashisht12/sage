# Synthetic Data Generator

Generate synthetic Q&A pairs from a knowledge base using Claude CLI for RAG evaluation.

## Quick Start

```bash
# 1. Install requirements
brew install jq
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Generate synthetic data
./generate.sh

# 3. (Optional) Upload to LangSmith
cp example.env .env
# Edit .env with your LANGSMITH_API_KEY
./upload_langsmith.sh
```

## Requirements

| Tool | Installation | Purpose |
|------|--------------|---------|
| Claude CLI | [Download](https://claude.ai/download) | Generate Q&A pairs |
| jq | `brew install jq` | JSON processing |
| uv | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | Python package manager |

Python dependencies (`langsmith`) are auto-managed by `uv` - no manual install needed.

## Usage

### 1. Generate Synthetic Data

```bash
./generate.sh
```

The script will interactively prompt for:
- **KB path** (required): Directory containing markdown files
- **queries.json path** (optional): Real user queries for style reference

**Features:**
- Progress display with percentage and question counts
- Answer validation (95% fuzzy match against source)
- Question deduplication (95% fuzzy match)
- Resume capability if interrupted
- Rejected pairs logged separately

**Output:**
- `output.jsonl` - Valid Q&A pairs
- `rejected.jsonl` - Failed validations with reasons

### 2. Upload to LangSmith

```bash
# Setup credentials
cp example.env .env
# Edit .env and add your LANGSMITH_API_KEY

# Upload
./upload_langsmith.sh
```

Get your API key from: https://smith.langchain.com/settings

## File Structure

```
├── generate.sh              # Main generation script
├── upload_langsmith.sh      # LangSmith upload script
├── prompt.md                # Prompt template (customizable)
├── CLAUDE.md                # Claude instructions
├── pyproject.toml           # Python dependencies
├── example.env              # Environment template
├── helpers/
│   ├── validate.py          # Fuzzy matching & deduplication
│   └── upload_langsmith.py  # LangSmith upload logic
├── kb/                      # Your knowledge base (markdown files)
└── queries/                 # Optional user queries
    └── queries.json
```

## Knowledge Base Format

Place markdown files in your KB directory. Two formats supported:

**With YAML frontmatter:**
```markdown
---
url: https://example.com/docs/page
title: Page Title
---

# Content

Your content here...
```

**Plain markdown:**
```markdown
# Content

Just content, no metadata...
```

## Queries JSON Format (Optional)

```json
{
  "metadata": {
    "total_queries": 10,
    "type": "Valid Queries"
  },
  "queries": [
    {"query": "How do I reset my password?", "topic": "account"},
    {"query": "What are the pricing tiers?", "topic": "billing"}
  ]
}
```

## Output Schema

Each line in `output.jsonl`:

```json
{
  "question": "What is the refund policy?",
  "answer": "Refunds are available within **30 days** of purchase.",
  "category": "billing",
  "subcategory": "refunds",
  "chunks": ["Full paragraph containing the answer..."],
  "source": ["https://example.com/docs/billing"]
}
```

| Field | Type | Description |
|-------|------|-------------|
| question | string | The synthetic question |
| answer | string | Exact excerpt from source (word-for-word) |
| category | string | Topic category |
| subcategory | string? | More specific classification |
| chunks | string[] | Relevant text passages from source |
| source | string[] | Source URLs or filenames |

## Configuration

### Q&A Pairs Per Page

Claude automatically decides based on content length:
- Short pages: 2-5 pairs
- Medium pages: 5-10 pairs
- Long pages: 10-15 pairs
- Maximum: 15 per page

### Validation Thresholds

| Check | Threshold | Action if failed |
|-------|-----------|------------------|
| Answer match | 95% fuzzy | Rejected |
| Question duplicate | 95% fuzzy | Rejected |

### Resume Capability

If interrupted, the script saves progress to `.generation_state.json`. On restart:

```
Found previous session with 3/15 files processed. Resume? [Y/n]
```

## Customization

### Modify the Prompt

Edit `prompt.md` to customize:
- Question types generated
- Output format
- Category guidelines
- Number of pairs per page

### Environment Variables

```bash
# .env file
LANGSMITH_API_KEY=your_api_key
LANGSMITH_ENDPOINT=https://api.smith.langchain.com  # Optional
LANGSMITH_DATASET_NAME=my-dataset                    # Optional
```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  For each markdown file:                                    │
│                                                             │
│  1. Extract content & metadata                              │
│  2. Build prompt (content + template + queries)             │
│  3. Call Claude CLI (fresh context per file)                │
│  4. Parse JSON response                                     │
│  5. Validate answers exist in source (95% fuzzy)            │
│  6. Check questions are unique (95% fuzzy)                  │
│  7. Append valid pairs to output.jsonl                      │
│  8. Log rejected pairs to rejected.jsonl                    │
│  9. Save state for resume                                   │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### "Claude CLI not found"
Install from https://claude.ai/download

### "jq not found"
```bash
brew install jq
```

### "uv not found"
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Validation rejecting too many answers
The 95% fuzzy match threshold may be too strict. Check `rejected.jsonl` to see similarity scores. You can adjust the threshold in `helpers/validate.py`.

### Resume not working
Delete `.generation_state.json` to start fresh:
```bash
rm .generation_state.json
```

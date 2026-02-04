# SAGE — Synthetic Autonomous Generation Engine

Generate synthetic query-citation pairs from a knowledge base using Claude CLI for RAG evaluation. Uses a two-call pipeline (Sonnet for queries, Haiku for citations) with exact span validation. Includes quality analysis and an iterative prompt improvement loop.

## Quick Start

```bash
# 1. Install requirements
brew install jq
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Generate synthetic data (sample 10 files)
./generate.sh --kb-path ./kb --queries-path ./queries/queries.json --sample 10

# 3. Analyze quality against real queries
./analysis.sh

# 4. Improve prompt based on analysis
./improve_prompt.sh

# 5. Or run the full automated pipeline
./run_pipeline.sh --kb-path ./kb --queries-path ./queries/queries.json

# 6. (Optional) Upload to LangSmith
cp example.env .env
# Edit .env with your LANGSMITH_API_KEY
./upload_langsmith.sh
```

## Requirements

| Tool | Installation | Purpose |
|------|--------------|---------|
| Claude CLI | [Download](https://claude.ai/download) | Generate queries & extract citations |
| jq | `brew install jq` | JSON processing |
| uv | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | Python package manager |

Python dependencies (`langsmith`) are auto-managed by `uv` - no manual install needed.

## Architecture

The generation pipeline uses two Claude calls per KB file:

```
KB Directory  ──[--sample N]──→  N random files
       │
  ┌────┴────┐
  │ Phase 1 │  Call 1 per file (Sonnet, parallel ×20)
  │         │  prompt.md → generates diverse queries + metadata
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

**Why two calls?**
- **Call 1 (Sonnet)** focuses on generating realistic, diverse queries — typos, multilingual, varied tone/style — without the constraint of finding exact citations
- **Call 2 (Haiku)** focuses purely on finding exact verbatim text in the document, which is a simpler task suited for a faster/cheaper model
- This separation improves both query diversity and citation accuracy

## Usage

### 1. Generate Synthetic Data

```bash
./generate.sh --kb-path ./kb --queries-path ./queries/queries.json --sample 8
```

**CLI flags:**

| Flag | Description | Default |
|------|-------------|---------|
| `--kb-path <dir>` | Knowledge base directory | prompt user |
| `--queries-path <file>` | Real user queries for style reference | prompt user |
| `--sample N` | Randomly select N files from KB | all files |
| `--no-resume` | Start fresh, ignore saved state | resume if available |

**Environment variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `MAX_PARALLEL` | Max concurrent Claude calls | 20 |

**Features:**
- Two-phase parallel generation (Sonnet → Haiku)
- Exact citation validation with character span computation
- Question deduplication (95% fuzzy match)
- Resume capability if interrupted
- Rejected pairs logged with reasons

**Output:**
- `output.jsonl` - Valid query-citation pairs with spans
- `rejected.jsonl` - Failed validations with reasons

### 2. Analyze Synthetic Data Quality

```bash
./analysis.sh
```

The script will interactively prompt for:
- **Synthetic data path** (required): Path to `output.jsonl`
- **Real queries path** (required): Path to real production queries JSON

**What it does:**
- Sends both datasets to Claude CLI for comparison
- Scores 8 dimensions (0-100%) with letter grades:
  - Language distribution
  - Typos & messiness
  - Query length & complexity
  - Topic coverage (2x weight)
  - Intent & behavior (2x weight)
  - Tone & formality
  - Formatting artifacts
  - Question style
- Calculates weighted overall similarity score
- Provides actionable recommendations

**Output:**
- `analysis_report.md` - Full report with scores, examples, and recommendations
- Summary table displayed in terminal

### 3. Improve Prompt (Iterative Loop)

```bash
./improve_prompt.sh
```

The script will interactively prompt for:
- **Real queries path** (required): Path to real production queries JSON

**What it does:**
- Reads the current `prompt.md` and `analysis_report.md`
- Samples 15 diverse real queries as style reference
- Sends everything to Claude CLI to generate an improved prompt
- Shows a diff of proposed changes
- Asks for approval before applying

**Before applying changes, it backs up the current version:**
```
backups/
├── v1/
│   ├── prompt.md              # The prompt used
│   ├── output.jsonl           # The synthetic data generated
│   ├── analysis_report.md     # The analysis that triggered changes
│   └── metadata.json          # Run metadata (score, timestamp, counts)
├── v2/
│   └── ...
```

**The iterative improvement loop:**
```
./generate.sh → ./analysis.sh → ./improve_prompt.sh → (repeat)
     ↓               ↓                ↓
 output.jsonl   analysis_report.md   prompt.md (improved)
```

Each iteration should produce a higher analysis score as the prompt gets refined.

### 4. Automated Pipeline

```bash
./run_pipeline.sh
```

Automates the full feedback loop: **generate -> analyze -> (improve -> generate -> analyze)** until the target score is reached or max iterations are exhausted.

**CLI flags (skip interactive prompts):**

| Flag | Description | Default |
|------|-------------|---------|
| `--kb-path <dir>` | Knowledge base directory | prompt user |
| `--queries-path <file>` | Real production queries JSON | prompt user |
| `--max-iterations <n>` | Maximum iteration count | 10 |
| `--target-score <n>` | Target similarity score (0-100) | 85 |

**Example (fully non-interactive):**
```bash
./run_pipeline.sh \
  --kb-path ./kb \
  --queries-path ./queries/queries.json \
  --max-iterations 5 \
  --target-score 70
```

### 5. Upload to LangSmith

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
├── generate.sh              # Two-call generation pipeline
├── prompt.md                # Call 1 prompt — generate queries only (Sonnet)
├── citation_prompt.md       # Call 2 prompt — extract verbatim citations (Haiku)
├── analysis.sh              # Analyze quality against real queries
├── improve_prompt.sh        # Improve prompt based on analysis
├── run_pipeline.sh          # Automated feedback loop
├── upload_langsmith.sh      # Upload to LangSmith
├── CLAUDE.md                # Claude instructions
├── pyproject.toml           # Python dependencies
├── example.env              # Environment template
├── helpers/
│   ├── validate.py          # Exact citation matching & span computation
│   └── upload_langsmith.py  # LangSmith upload logic
├── backups/                 # Version history (auto-created)
│   └── v1/
│       ├── prompt.md
│       ├── output.jsonl
│       ├── analysis_report.md
│       └── metadata.json
├── kb/                      # Your knowledge base (markdown files)
└── queries/                 # Real user queries
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
  "query": "whats ur refund polcy?",
  "doc_id": "refund-policy.md",
  "citation": "Refunds are available within **30 days** of purchase.",
  "start_index": 1842,
  "end_index": 1892,
  "category": "billing",
  "subcategory": "refunds",
  "chunks": ["Full paragraph containing the citation..."],
  "source": ["https://example.com/docs/billing"],
  "query_metadata": {
    "language": "en",
    "has_typos": true,
    "tone": "casual",
    "style": "question"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| query | string | Realistic user input (may contain typos, non-English, etc.) |
| doc_id | string | KB filename the citation comes from |
| citation | string | Exact verbatim text from source document |
| start_index | int | Character offset where citation begins in source |
| end_index | int | Character offset where citation ends in source |
| category | string | Topic category |
| subcategory | string? | More specific classification |
| chunks | string[] | Broader passages containing the citation |
| source | string[] | Source URLs or filenames |
| query_metadata | object | Language, typos, tone, style metadata |

**Span verification:** `source_content[start_index:end_index] == citation`

## Configuration

### Queries Per Page

Claude automatically decides based on content length:
- Short pages: 3-5 queries
- Medium pages: 5-8 queries
- Long pages: 8-10 queries
- Maximum: 10 per page

### Validation

| Check | Method | Action if failed |
|-------|--------|------------------|
| Citation match | Exact `str.find()` + whitespace normalization fallback | Rejected (`citation_not_found`) |
| Null citation | Citation returned as null by Haiku | Rejected (`citation_null`) |
| Question duplicate | 95% fuzzy match | Rejected (`duplicate_question`) |

### Resume Capability

If interrupted, the script saves progress to `.generation_state.json`. On restart:

```
Found previous session with 3/15 files processed. Resume? [Y/n]
```

## Customization

### Modify the Prompts

- Edit `prompt.md` to customize query generation (types, tone, language distribution)
- Edit `citation_prompt.md` to customize citation extraction rules

### Environment Variables

```bash
# .env file
LANGSMITH_API_KEY=your_api_key
LANGSMITH_ENDPOINT=https://api.smith.langchain.com  # Optional
LANGSMITH_DATASET_NAME=my-dataset                    # Optional
```

```bash
# Shell environment
MAX_PARALLEL=10 ./generate.sh --kb-path ./kb  # Limit concurrent calls
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

### Too many citations rejected
Check `rejected.jsonl` for `citation_not_found` entries. This means Haiku's extracted text didn't exactly match the source. The whitespace normalization fallback handles minor differences, but paraphrased citations will be rejected by design.

### Resume not working
Delete `.generation_state.json` to start fresh:
```bash
rm .generation_state.json
```
Or use the `--no-resume` flag.

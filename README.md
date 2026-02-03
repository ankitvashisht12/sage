# SAGE — Synthetic Autonomous Generation Engine

Generate synthetic Q&A pairs from a knowledge base using Claude CLI for RAG evaluation. SAGE includes quality analysis and an iterative prompt improvement loop that automatically refines generation prompts until synthetic data closely matches real production queries.

## Quick Start

```bash
# 1. Install requirements
brew install jq
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Generate synthetic data
./generate.sh

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

**Example output:**
```
Synthetic Data Analyzer
========================

Enter path to synthetic data (output.jsonl): ./output.jsonl
Enter path to real production queries (queries.json): ./queries/tagged_queries.json

Loaded 65 synthetic Q&A pairs
Loaded 287 real production queries

Running analysis with Claude CLI...

Analysis complete!

  Report saved to: ./analysis_report.md

  Overall similarity score: 34%

  | Dimension             | Similarity | Grade |
  |-----------------------|-----------|-------|
  | Language Distribution | 10%       | F     |
  | Typos & Messiness     | 5%        | F     |
  | Topic Coverage        | 35%       | D     |
  | ...                   | ...       | ...   |
  | **Overall Score**     | **34%**   | **D** |
```

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

**What it does each iteration:**
1. Cleans previous output (state file, output.jsonl, rejected.jsonl)
2. Runs `generate.sh` with `--no-resume`
3. Runs `analysis.sh` to score quality
4. If score >= target: stops with success
5. Runs `improve_prompt.sh` to refine the prompt
6. Repeats

**Error handling:**
- Generation or analysis failure stops the pipeline immediately
- Prompt improvement failure is tolerated once; 2 consecutive failures stops the pipeline
- Ctrl+C prints a partial summary table

**Output:**
```
  Iteration  |  Score  |  Delta
  -----------+---------+--------
      1      |   27%   |    -
      2      |   45%   |  +18%
      3      |   62%   |  +17%
      4      |   78%   |  +16%
      5      |   86%   |   +8%

  Result: TARGET REACHED (86% >= 85%)
  Total iterations: 5
  Total improvement: +59%
```

**CLI args for individual scripts:**

All three scripts also accept CLI arguments for non-interactive use:

```bash
# generate.sh
./generate.sh --kb-path ./kb --queries-path ./queries/queries.json --no-resume

# analysis.sh
./analysis.sh --synthetic-path ./output.jsonl --queries-path ./queries/queries.json

# improve_prompt.sh
./improve_prompt.sh --queries-path ./queries/queries.json
```

When no flags are provided, each script falls back to its original interactive prompts.

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
├── generate.sh              # Generate synthetic Q&A pairs
├── analysis.sh              # Analyze quality against real queries
├── improve_prompt.sh        # Improve prompt based on analysis
├── run_pipeline.sh          # Automated feedback loop (generate->analyze->improve)
├── upload_langsmith.sh      # Upload to LangSmith
├── prompt.md                # Generation prompt template
├── analysis_prompt.md       # Analysis prompt template
├── improve_prompt_template.md # Prompt improvement template
├── CLAUDE.md                # Claude instructions
├── pyproject.toml           # Python dependencies
├── example.env              # Environment template
├── helpers/
│   ├── validate.py          # Fuzzy matching & deduplication
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

### Generation Pipeline

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

### Analysis Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  1. Load synthetic data (output.jsonl)                      │
│  2. Load real production queries (queries.json)             │
│  3. Build analysis prompt with both datasets                │
│  4. Call Claude CLI for comparison                          │
│  5. Score 8 dimensions (0-100%)                             │
│  6. Calculate weighted overall score                        │
│  7. Generate report with examples & recommendations         │
│  8. Save to analysis_report.md                              │
└─────────────────────────────────────────────────────────────┘
```

### Improvement Loop

```
┌─────────────────────────────────────────────────────────────┐
│  1. Read current prompt.md                                  │
│  2. Read analysis_report.md (gaps identified)               │
│  3. Sample 15 diverse real queries as style reference        │
│  4. Call Claude CLI to generate improved prompt              │
│  5. Show diff of changes                                    │
│  6. Ask for user approval                                   │
│  7. Backup current version (prompt + output + report)       │
│  8. Apply improved prompt                                   │
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

# Synthetic vs Real Query Analysis

You are an expert data analyst specializing in NLP and conversational AI evaluation. Your task is to compare synthetic Q&A data against real production queries and produce a detailed analysis report.

---

## Input Data

### Synthetic Queries (from output.jsonl)

<synthetic_queries>
{{SYNTHETIC_QUERIES}}
</synthetic_queries>

### Real Production Queries

<real_queries>
{{REAL_QUERIES}}
</real_queries>

---

## Analysis Dimensions

Analyze the following dimensions and for each one, give a similarity score from 0-100%:

### 1. Language Distribution
- What percentage of real queries are non-English?
- Does the synthetic data reflect this multilingual nature?
- List the languages found in real queries vs synthetic.

### 2. Typos, Grammar & Messiness
- How frequent are typos and grammatical errors in real queries?
- Does the synthetic data replicate this messiness?
- Provide examples from both datasets.

### 3. Query Length & Complexity
- What is the length distribution in real queries (short/medium/long)?
- Does synthetic data match this distribution?
- Compare min/max/average word counts.

### 4. Topic Coverage
- What are the top topics in real queries (by frequency)?
- What are the top topics in synthetic queries?
- Which real-world topics are missing from synthetic data?
- Which synthetic topics are overrepresented vs real usage?

### 5. Intent & Behavior
- What intents do real users express (buying, building, troubleshooting, comparing, etc.)?
- Does synthetic data capture these intents?
- Are there behavioral patterns in real queries absent from synthetic?

### 6. Tone & Formality
- What is the tone distribution in real queries (casual, formal, urgent, frustrated)?
- Does synthetic data match this tone?
- Provide examples.

### 7. Formatting Artifacts
- Do real queries contain HTML tags, pipe separators, URLs, ALL CAPS, etc.?
- Does synthetic data replicate these artifacts?

### 8. Question Style
- How do real users phrase questions (direct, descriptive, conversational)?
- How do synthetic questions compare?
- Are real queries more like statements/requests vs actual questions?

---

## Output Format

Produce the report in the following markdown format:

```
# Synthetic Data Quality Report

## Summary

| Dimension | Similarity Score | Grade |
|-----------|-----------------|-------|
| Language Distribution | X% | A/B/C/D/F |
| Typos & Messiness | X% | A/B/C/D/F |
| Query Length & Complexity | X% | A/B/C/D/F |
| Topic Coverage | X% | A/B/C/D/F |
| Intent & Behavior | X% | A/B/C/D/F |
| Tone & Formality | X% | A/B/C/D/F |
| Formatting Artifacts | X% | A/B/C/D/F |
| Question Style | X% | A/B/C/D/F |
| **Overall Score** | **X%** | **X** |

## Overall Verdict

[2-3 sentence summary of how close the synthetic data is to real-world usage]

## Detailed Analysis

### 1. Language Distribution (X%)
[Detailed analysis with examples]

### 2. Typos & Messiness (X%)
[Detailed analysis with examples]

... (continue for all dimensions)

## Recommendations

[Specific, actionable recommendations to improve the synthetic data quality]

## Methodology

[Brief description of how scores were calculated]
```

### Grading Scale
- A (90-100%): Excellent match
- B (75-89%): Good match with minor gaps
- C (50-74%): Moderate match with notable gaps
- D (25-49%): Poor match with significant gaps
- F (0-24%): Very poor match

---

## Instructions

1. Be rigorous and objective. Do not inflate scores.
2. Use concrete examples from both datasets to support each score.
3. The overall score should be a weighted average where Topic Coverage and Intent & Behavior carry 2x weight (they matter most for RAG evaluation).
4. Provide specific, actionable recommendations.
5. Output ONLY the markdown report, no additional text.

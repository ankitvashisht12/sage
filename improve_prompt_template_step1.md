# Step 1: Analyze Gaps and Produce a Change Plan

You are an expert prompt engineer. You are given a synthetic data generation prompt, an analysis report comparing its output against real production queries, and samples of real queries.

Your task is to produce a **structured change plan** that describes exactly what modifications should be made to the prompt to improve the quality of generated synthetic data.

---

## Current Generation Prompt

<current_prompt>
{{CURRENT_PROMPT}}
</current_prompt>

## Analysis Report

<analysis_report>
{{ANALYSIS_REPORT}}
</analysis_report>

## Real Query Samples

<real_query_samples>
{{REAL_QUERY_SAMPLES}}
</real_query_samples>

---

## Your Task

Analyze the gaps between synthetic and real data. Then produce a change plan as a JSON array of operations to apply to the prompt.

Think carefully about:
- What is the prompt missing that causes the gaps?
- What existing instructions are good and should stay?
- What needs to be added, modified, or restructured?
- Are there real query examples worth embedding directly in the prompt?

The change plan should be specific enough that another agent can apply it mechanically to produce the improved prompt.

---

## Output Format

Output a JSON object with this structure:

```json
{
  "summary": "Brief summary of what the changes aim to fix",
  "overall_strategy": "High-level description of the improvement approach",
  "changes": [
    {
      "action": "ADD | MODIFY | REMOVE | RESTRUCTURE",
      "target": "Which section or rule this affects",
      "description": "What specifically to do",
      "content": "The actual text/content to add or replace with (if applicable)",
      "reasoning": "Why this change is needed based on the analysis"
    }
  ],
  "real_query_examples": [
    {
      "query": "The actual real query text",
      "why_included": "What this example demonstrates (e.g., typo, multilingual, casual tone)"
    }
  ]
}
```

### Guidelines for Changes

- Each change should map to a specific gap from the analysis report
- If the analysis shows a dimension scoring well, do not change what drives that score
- For topic coverage gaps: acknowledge these depend on KB content, do not instruct the model to hallucinate topics
- For style/format gaps: these CAN be fixed by prompt changes
- Select 10-15 real query examples that demonstrate the diversity missing from synthetic data
- Be specific in the "content" field - write the actual text to insert, not vague instructions

---

## Output

CRITICAL: You are a JSON-producing function. Your entire response must be a single valid JSON object and nothing else.

Rules:
- Do NOT wrap in ```json code blocks
- Do NOT add any preamble, explanation, or commentary before or after the JSON
- The very first character of your response MUST be `{`
- The very last character of your response MUST be `}`
- If you violate these rules, the pipeline will fail

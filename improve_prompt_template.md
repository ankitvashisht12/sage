# Prompt Improvement Task

You are an expert prompt engineer. Your task is to improve a synthetic data generation prompt based on a quality analysis report that compares the generated data against real production queries.

---

## Current Generation Prompt

<current_prompt>
{{CURRENT_PROMPT}}
</current_prompt>

## Analysis Report

This report shows how the synthetic data (generated using the above prompt) compared against real production queries:

<analysis_report>
{{ANALYSIS_REPORT}}
</analysis_report>

## Real Query Samples (Style Reference)

These are actual production queries from real users. Study their style, tone, language, messiness, and patterns:

<real_query_samples>
{{REAL_QUERY_SAMPLES}}
</real_query_samples>

---

## Your Objective

Rewrite the generation prompt to address the gaps identified in the analysis report. The improved prompt should produce synthetic queries that more closely match real-world usage patterns.

## Improvement Guidelines

### Focus On Style & Format Gaps (Prompt Can Fix These)

1. **Language diversity**: If real queries are multilingual, instruct the model to generate a percentage of non-English queries in the languages observed.

2. **Typos and messiness**: If real queries have typos, broken grammar, and informal language, instruct the model to realistically introduce these in a percentage of queries.

3. **Query length variation**: If real queries range from 2-word fragments to 200-word paragraphs, instruct the model to vary length accordingly.

4. **Tone diversity**: If real queries range from casual to formal to frustrated, instruct the model to generate across this spectrum.

5. **Intent diversity**: If real users ask with buying intent, troubleshooting intent, comparison intent, etc., instruct the model to generate these varied intents.

6. **Formatting artifacts**: If real queries contain HTML tags, pipe separators, ALL CAPS, URLs, etc., instruct the model to occasionally include these.

7. **Question style**: If real users write statements/requests rather than formal questions, instruct the model to mimic this.

### Acknowledge Topic Gaps (Prompt Cannot Fully Fix These)

If the analysis shows topic coverage gaps (e.g., real users ask about WhatsApp but the KB has no WhatsApp content), do NOT instruct the model to invent topics outside the KB. Instead:
- Add a note acknowledging that topic coverage depends on KB content
- Suggest the model generate questions at the boundary of what the KB covers

### Preserve What Works

- Keep all existing rules that scored well (exact citations, chunks, JSON schema)
- Keep the output format unchanged
- Keep the validation checklist

### Use Real Queries as Examples

Embed 10-15 diverse real query samples directly in the prompt as style reference. Pick queries that show:
- Different languages
- Typos and informal language
- Various lengths (short, medium, long)
- Different intents
- Different tones

---

## Output Requirements

1. Output ONLY the complete improved prompt (ready to save as `prompt.md`)
2. Do not include any explanations, commentary, or meta-text
3. The improved prompt must be a complete, self-contained prompt file
4. Keep all placeholders: `{{KB_CONTENT}}`, `{{SOURCE_METADATA}}`, `{{USER_QUERIES}}`
5. Keep the JSON output schema exactly the same
6. Keep the existing example output section (update if needed)

---

## Output

Now output the complete improved `prompt.md` file:

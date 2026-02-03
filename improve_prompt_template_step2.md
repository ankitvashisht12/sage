# Step 2: Apply Change Plan to Prompt

You are a technical writer. You are given an existing prompt file and a structured change plan. Your job is to apply the changes and output the complete, updated prompt file.

---

## Original Prompt

<original_prompt>
{{ORIGINAL_PROMPT}}
</original_prompt>

## Change Plan

<change_plan>
{{CHANGE_PLAN}}
</change_plan>

---

## Instructions

1. Start with the original prompt as your base
2. Apply each change from the change plan in order
3. For ADD actions: insert the new content at the specified location
4. For MODIFY actions: update the specified section with the new content
5. For REMOVE actions: remove the specified content
6. For RESTRUCTURE actions: reorganize as described
7. Integrate the real query examples from the change plan into the prompt where appropriate
8. Ensure the final prompt flows naturally - it should read as a cohesive document, not a patchwork

## Critical Requirements

- Your entire response IS the prompt file. Nothing else.
- Do not explain what you changed. Do not add preamble. Do not ask questions.
- The first line of your response must be the first line of the prompt (e.g., `# Synthetic Q&A Generation Task`)
- The prompt must contain these placeholders exactly: `{{KB_CONTENT}}`, `{{SOURCE_METADATA}}`, `{{USER_QUERIES}}`
- The JSON schema for the output must remain identical to the original
- The prompt must be complete and self-contained - ready to use as-is
- Do not wrap your response in code blocks

## Output

Generate the complete updated prompt file now:

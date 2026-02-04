# Verbatim Citation Extraction

You are an expert at identifying relevant text in documents. Your task is to find exact verbatim passages from a document that answer each given question.

---

## Document

<document>
{{KB_CONTENT}}
</document>

## Questions

<questions>
{{QUESTIONS}}
</questions>

---

## Task

For EACH question above, find the exact passage(s) from the document that are relevant to the question. Copy text **VERBATIM** — do not paraphrase, summarize, or modify in any way.

### Rules

1. **Exact match required**: Each citation must appear EXACTLY (character-for-character) in the document above
2. **Preserve formatting**: Keep all markdown formatting (`**bold**`, `[links](url)`, `- list items`, etc.)
3. **Preserve punctuation and spacing**: Do not alter any characters, whitespace, or line breaks
4. **Prefer informative passages**: Select passages that meaningfully answer the question — not just headings or single words
5. **Null if not found**: If no relevant passage exists for a question, set citation to `null`
6. **Chunks for context**: Include the broader paragraph or section containing the citation

### Output Format

Output valid JSON only. No explanations, no markdown code blocks, just raw JSON:

```json
{
  "citations": [
    {
      "query": "the original question exactly as given",
      "citation": "exact verbatim text from document",
      "chunks": ["broader paragraph or section containing the citation"]
    }
  ]
}
```

### Important Notes

- The `citation` field must be a substring that appears exactly in the document — if you were to search for it in the document text, it would match character-for-character
- The `chunks` field should contain the broader context (full paragraph, full list, or full section) where the citation appears
- If a question could be answered by multiple passages, pick the single most relevant one
- If the question is in a different language than the document, still find the relevant English passage from the document
- Maintain the same order as the input questions

---

## Output

Now extract verbatim citations for each question. Output ONLY valid JSON, no additional text or explanation.

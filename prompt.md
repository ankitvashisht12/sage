# Synthetic Q&A Generation Task

You are an expert at generating high-quality question and answer pairs for RAG (Retrieval-Augmented Generation) evaluation. Your task is to create realistic, diverse questions based on the provided knowledge base content.

---

## Your Objective

Generate question-answer pairs where:
1. Questions are natural and reflect how real users would ask
2. Answers are **exact excerpts** from the source content (word-for-word citations)
3. Each pair includes the relevant chunks that contain the answer

---

## Input Context

### Knowledge Base Content

<kb_content>
{{KB_CONTENT}}
</kb_content>

### Source Metadata

<source_metadata>
{{SOURCE_METADATA}}
</source_metadata>

### Real User Queries (for style reference)

<user_queries>
{{USER_QUERIES}}
</user_queries>

---

## Output Requirements

Generate an appropriate number of question-answer pairs based on the content depth and length:
- **Short/simple pages**: 2-5 pairs
- **Medium pages**: 5-10 pairs
- **Long/detailed pages**: 10-15 pairs

**Maximum: 15 pairs per page. Quality over quantity.**

Output in valid JSON format.

### JSON Schema

```json
{
  "pairs": [
    {
      "question": "string - A natural question a user might ask",
      "answer": "string - EXACT text excerpt from the source that answers the question",
      "category": "string - Primary topic category",
      "subcategory": "string or null - More specific classification",
      "chunks": ["string array - Relevant text passages from the source"],
      "source": ["string array - Source URLs or identifiers"]
    }
  ]
}
```

---

## Critical Rules

### Rule 1: Answers Must Be Exact Citations

The `answer` field MUST contain text that appears **exactly** in the source content. This includes:
- Exact wording (no paraphrasing)
- Original markdown formatting (links, bold, italics)
- Original punctuation and spacing

**WRONG:**
```json
{
  "question": "What is the refund policy?",
  "answer": "You can get a refund within thirty days"
}
```

**CORRECT:**
```json
{
  "question": "What is the refund policy?",
  "answer": "Refunds are available within 30 days of purchase."
}
```

### Rule 2: Chunks Provide Context

The `chunks` array should contain the broader text passages (paragraphs or sections) from which the answer is extracted. These help establish context for RAG evaluation.

### Rule 3: Question Diversity

Generate diverse question types:
- **Factual**: "What is X?" / "How many Y?"
- **Procedural**: "How do I...?" / "What are the steps to...?"
- **Comparison**: "What's the difference between X and Y?"
- **Conditional**: "What happens if...?" / "Can I do X when Y?"
- **Troubleshooting**: "Why is X not working?" / "How to fix...?"

### Rule 4: Match User Query Style

If real user queries are provided, analyze their:
- Tone (formal vs casual)
- Complexity (simple vs detailed)
- Common patterns and phrasing

Generate questions that match this style.

### Rule 5: Category Assignment

Assign appropriate categories based on the content topic. Use consistent category names across the dataset. Examples:
- `billing`, `account_management`, `features`, `integrations`
- `troubleshooting`, `getting_started`, `api_reference`, `security`

---

## Example Output

Given this source content:
```
## Pricing Plans

We offer three pricing tiers:

**Starter Plan** - $9/month
- Up to 1,000 API calls
- Email support
- Basic analytics

**Pro Plan** - $29/month
- Up to 10,000 API calls
- Priority support
- Advanced analytics
- Custom integrations
```

Generate output like:
```json
{
  "pairs": [
    {
      "question": "How much does the Pro Plan cost?",
      "answer": "**Pro Plan** - $29/month",
      "category": "pricing",
      "subcategory": "plans",
      "chunks": [
        "**Pro Plan** - $29/month\n- Up to 10,000 API calls\n- Priority support\n- Advanced analytics\n- Custom integrations"
      ],
      "source": ["https://example.com/pricing"]
    },
    {
      "question": "What features are included in the Starter Plan?",
      "answer": "- Up to 1,000 API calls\n- Email support\n- Basic analytics",
      "category": "pricing",
      "subcategory": "features",
      "chunks": [
        "**Starter Plan** - $9/month\n- Up to 1,000 API calls\n- Email support\n- Basic analytics"
      ],
      "source": ["https://example.com/pricing"]
    },
    {
      "question": "How many API calls can I make on the Pro Plan?",
      "answer": "Up to 10,000 API calls",
      "category": "pricing",
      "subcategory": "limits",
      "chunks": [
        "**Pro Plan** - $29/month\n- Up to 10,000 API calls\n- Priority support\n- Advanced analytics\n- Custom integrations"
      ],
      "source": ["https://example.com/pricing"]
    }
  ]
}
```

---

## Final Checklist

Before outputting, verify:
- [ ] All answers are exact quotes from the source
- [ ] Chunks contain the text passages where answers appear
- [ ] Questions are diverse and natural
- [ ] Categories are consistent and meaningful
- [ ] JSON is valid and properly formatted
- [ ] Source URLs/identifiers are included

---

## Output

Now generate the Q&A pairs based on the provided knowledge base content. Output ONLY valid JSON, no additional text or explanation.

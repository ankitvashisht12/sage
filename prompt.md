# Realistic Production Traffic Simulation — Q&A Generation Task

You are an expert at generating realistic, diverse query-answer pairs for RAG (Retrieval-Augmented Generation) evaluation. Your task is to simulate real production chatbot traffic — with all its messiness, diversity, and unpredictability — based on the provided knowledge base content.

---

## Your Objective

Generate query-answer pairs that **simulate real production traffic** to a chatbot widget. This means:
1. Queries look like they come from diverse real users — not a clean FAQ list
2. Queries include the full spectrum of human messiness: typos, multiple languages, casual tone, formatting artifacts, varied lengths
3. Answers are **exact excerpts** from the source content (word-for-word citations)
4. Each pair includes the relevant chunks that contain the answer
5. The topic and intent distribution matches real-world patterns, not just what's easiest to extract

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

Generate an appropriate number of query-answer pairs based on the content depth and length:
- **Short/simple pages**: 5-8 pairs
- **Medium pages**: 8-15 pairs
- **Long/detailed pages**: 15-25 pairs

**Maximum: 25 pairs per page.** More pairs are needed to achieve the required diversity across languages, tones, styles, and query types while maintaining quality.

Output in valid JSON format.

### JSON Schema

```json
{
  "pairs": [
    {
      "query": "string - A realistic user input (question, statement, command, or description)",
      "answer": "string - EXACT text excerpt from the source that answers/addresses the query",
      "category": "string - Primary topic category",
      "subcategory": "string or null - More specific classification",
      "chunks": ["string array - Relevant text passages from the source"],
      "source": ["string array - Source URLs or identifiers"],
      "query_metadata": {
        "language": "string - ISO 639-1 code (en, es, fr, it, pt, hi, de, etc.)",
        "has_typos": "boolean - whether the query intentionally contains typos",
        "tone": "string - casual | formal | frustrated | neutral",
        "style": "string - question | statement | use_case | command | conversational"
      }
    }
  ]
}

---

## Realism Requirements

Your generated queries must simulate real production traffic, not clean FAQ-style questions. Follow these distribution targets:

### Language Distribution
- **85-90% English** queries
- **10-15% non-English** queries, distributed across: Spanish, Italian, French, Portuguese, Hindi/Hinglish, German, and other languages
- Non-English queries should be written naturally in that language, not translated from English
- Examples: "quanto costa un vostro bot?", "funciona en whatsapp?", "Aap kitni languages support krte ho?"

### Typos & Messiness (~8% of queries)
- Include realistic typos: transposed letters, missing spaces, doubled letters, phonetic misspellings
- Examples: "MONTLY SBUSCRIPTIOON", "automtoive repair comapny", "becaus eI fint", "anlayze"
- Some queries should have missing punctuation or run-on sentences
- Do NOT make every query messy — only ~8% should contain errors

### Query Length Distribution
- **~30% short** (1-8 words): "price per month", "free trial?", "funciona en whatsapp?"
- **~35% medium** (9-15 words): typical question-length queries
- **~35% long** (16+ words): paragraph-length messages describing business context, use cases, or multi-part requests
- Long query example: "ok hallo ich will einen KI Bot welcher mir ermöglicht Anfragen von Kunden automatisch zu beantworten und bei Bedarf an einen Mitarbeiter weiterzuleiten"

### Tone & Formality
- **~40% casual/conversational**: "thanks dude, but I have a question kind diferent", "hey can u help me set up a bot?"
- **~25% professional/formal**: "Good afternoon, I would like to inquire about the Partners program"
- **~5% urgent/frustrated**: "it is definitively a coding bug", "why isn't this working??"
- **~30% neutral/factual**: standard informational queries

### Query Style (NOT everything is a question)
- **~35% direct questions**: "What integrations do you support?"
- **~30% statements/requests**: "I need help with my bill", "price per month"
- **~20% use case descriptions**: "i want to a chat bot ai customer servise chat support so that my customer can get assisted by them"
- **~10% conversational/multi-part**: messages with greetings, context, then a question
- **~5% commands/imperatives**: "show me the Pre-Built Templates list"

### Formatting Artifacts (~10-15% of queries)
Real users paste content from other sources. Some queries should include:
- HTML entities: `&quot;`, `&amp;`, `<br />`
- Pipe separators: `||` between message parts
- URLs pasted inline
- ALL CAPS for emphasis
- Email addresses
- Quoted text from documentation with questions appended
- Example: `&quot;Tools can be dynamically selected per agent&quot;  Assign specific tools, roles, or tasks to individual agents.is this possible`
- Example: `tars have 4 teams product, marketing, customer success, sales<br />can u tell me more about this?`

---

## Real Query Reference Gallery

Study these real production queries carefully. Your output should be **indistinguishable** from this style:

### Multilingual
- `quanto costa un vostro bot?` (Italian - pricing)
- `funciona en whatsapp?` (Spanish - integration)
- `Aap kitni languages support krte ho?` (Hinglish - features)
- `Salut j'ai veux un chatbot` (French - chatbot creation)
- `Vc pode solicitar foto dos documentos e enviar para uma atendente humana?` (Portuguese - features)
- `vorrei capire se è amaricana inglese cinese...` (Italian - exploratory/confused)

### Messy / Typos
- `MONTLY SBUSCRIPTIOON BENFICAIL` (ALL CAPS + typos)
- `automtoive repair comapny` (typos in business description)
- `answers.how does it work` (missing space, run-on)
- `especiallyAlzheimer's` (missing space)

### Long / Use Case Description
- `can he help us with how the automations will work and how we can integrate that to our system?`
- `i want to a chat bot ai customer servise chat support so that my customer can get assisted by them`
- `I am interested in your whatsapp integration. More specifically, I would like to find out if you are an official whatsapp partner`

### Formatting Artifacts
- `&quot;Tools can be dynamically selected per agent&quot;  Assign specific tools, roles, or tasks to individual agents.is this possible`
- `tars have 4 teams product, marketing, customer success, sales<br />can u tell me more about this?`
- `Hi, does tars have &quot;Multi-turn dialogue capability & memory&quot;`

### Statements / Non-Questions
- `I need help with my bill` (statement of need)
- `price per month` (bare phrase)
- `hello i have a question - where you can create, customize, and deploy AI chatbots on your own.`

### Casual / Conversational
- `thanks dude, but I have a question kind diferent`
- `hey can u help me set up a bot?`

### Formal / Professional
- `Good afternoon, I would like to inquire about the 'Partners' program`
- `Were there hotels among your use cases? Can you tell the name?`

---

## Critical Rules

### Rule 1: Answers Must Be Exact Citations

The `answer` field MUST contain text that appears **exactly** in the source content. This includes:
- Exact wording (no paraphrasing)
- Original markdown formatting (links, bold, italics)
- Original punctuation and spacing

**Note**: The realism requirements (typos, multilingual, casual tone, formatting artifacts) apply to the `query` field ONLY. The `answer` field must always be a pristine, exact citation from the source.

**WRONG:**
```json
{
  "query": "What is the refund policy?",
  "answer": "You can get a refund within thirty days"
}

**CORRECT:**
```json
{
  "query": "whats ur refund polcy?",
  "answer": "Refunds are available within 30 days of purchase."
}

### Rule 2: Chunks Provide Context

The `chunks` array should contain the broader text passages (paragraphs or sections) from which the answer is extracted. These help establish context for RAG evaluation.

### Rule 3: Query Diversity

Generate diverse query types — note that real users do NOT always ask questions:

**Question formats (~35% of output):**
- Factual: "What is X?" / "How many Y?"
- Procedural: "How do I...?" / "What are the steps to...?"
- Comparison: "What's the difference between X and Y?"
- Conditional: "What happens if...?" / "Can I do X when Y?"
- Troubleshooting: "Why is X not working?" / "How to fix...?"

**Non-question formats (~65% of output):**
- Statements of need: "I need help with my bill", "i want to a chat bot ai customer servise chat support"
- Use case descriptions: "I have an automotive repair company and I want to automate customer scheduling and follow-ups"
- Commands: "show me the pricing plans", "tell me about WhatsApp integration"
- Context-then-question: "hello i have a question - where you can create, customize, and deploy AI chatbots on your own."
- Greetings with embedded queries: "Hi, does tars have multi-turn dialogue capability & memory"
- Bare phrases: "price per month", "free trial", "whatsapp integration"

### Rule 4: Match Real User Behavior

If real user queries are provided, deeply analyze and replicate:
- **Tone spectrum**: from "thanks dude" casual to "Good afternoon, I would like to inquire" formal
- **Messiness**: typos, grammar errors, missing punctuation, run-on sentences
- **Intent patterns**: users describing what they want to build, asking for demos, exploring partnerships
- **Message structure**: some users write multi-sentence paragraphs; others write 2-word fragments
- **Code-switching**: some users mix languages mid-sentence (Hinglish, Spanglish)
- **Copy-paste behavior**: users quoting documentation text and asking about it
- **Conversational openers**: "hi", "hello", "hey" before the actual query

Do NOT sanitize or clean up the query style. The goal is to produce queries that are indistinguishable from real user input, including all its imperfections.

### Rule 5: Category & Topic Balance

Assign categories based on content. **Critical**: match the real-world topic distribution, not just what's easiest to extract from the KB:

**Target distribution (approximate):**
- `chatbot_creation` (~20%): users wanting to build/customize bots for their business
- `pricing` (~13%): cost questions, plan comparisons
- `features_capabilities` (~10%): what the product can do
- `integrations` (~10%): WhatsApp, API, CRM, webhooks, third-party tools
- `customer_support` (~8%): using the product for support automation
- `white_label_reseller` (~6%): reselling, partnerships, branding
- `multilingual_support` (~5%): language support questions
- `demo_contact` (~5%): requesting demos, contacting sales
- `templates` (~4%): pre-built templates, industry-specific templates
- `lead_generation` (~3%): using bots for lead capture
- `general_inquiry` (~5%): broad product questions
- `troubleshooting` (~3%): bugs, errors, things not working
- `billing` (~2%): invoices, refunds, payment issues
- `account_management` (~2%): account settings, team management
- Other topics as relevant to the KB content (~4%)

**Important**: Only generate queries for topics that have supporting content in the KB. Do NOT hallucinate topics. But DO generate queries that approach the KB content from these diverse angles — the same pricing page can generate a chatbot_creation query ("I want to build a bot for my restaurant, which plan should I use?") alongside a pure pricing query.

---

## Anti-Patterns to Avoid

Do NOT generate output that looks like this:

1. **FAQ Extraction**: Every query is a clean, well-formed English question → Real users don't talk like this
2. **Uniform Tone**: Every query has the same neutral, professional tone → Real users range from "hey whats up" to "Good afternoon, I would like to inquire"
3. **Perfect Grammar**: Every query has perfect spelling and punctuation → Real users make typos (~8% of the time)
4. **English Only**: All queries in English → ~14% of real traffic is non-English
5. **Question Only**: Every entry starts with What/How/Why/Can → ~65% of real inputs are statements, commands, or descriptions
6. **Pricing Dominance**: Most queries about pricing/billing → Real traffic is dominated by chatbot_creation and integration questions
7. **Uniform Length**: All queries are 8-12 words → Real queries range from 2 words to 80+ words
8. **No Formatting Artifacts**: Clean text only → Real queries contain HTML entities, URLs, pipe separators

---

## Example Output

Given this source content:
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

Generate output like:
```json
{
  "pairs": [
    {
      "query": "quanto costa il piano Pro?",
      "answer": "**Pro Plan** - $29/month",
      "category": "pricing",
      "subcategory": "plans",
      "chunks": [
        "**Pro Plan** - $29/month\n- Up to 10,000 API calls\n- Priority support\n- Advanced analytics\n- Custom integrations"
      ],
      "source": ["https://example.com/pricing"],
      "query_metadata": {
        "language": "it",
        "has_typos": false,
        "tone": "neutral",
        "style": "question"
      }
    },
    {
      "query": "I have a small ecommerce busines and I need a chatbot for customer support, whats the cheapest plan that includes custom intgrations?",
      "answer": "**Pro Plan** - $29/month\n- Up to 10,000 API calls\n- Priority support\n- Advanced analytics\n- Custom integrations",
      "category": "chatbot_creation",
      "subcategory": "pricing",
      "chunks": [
        "We offer three pricing tiers:\n\n**Starter Plan** - $9/month\n- Up to 1,000 API calls\n- Email support\n- Basic analytics\n\n**Pro Plan** - $29/month\n- Up to 10,000 API calls\n- Priority support\n- Advanced analytics\n- Custom integrations"
      ],
      "source": ["https://example.com/pricing"],
      "query_metadata": {
        "language": "en",
        "has_typos": true,
        "tone": "casual",
        "style": "use_case"
      }
    },
    {
      "query": "price per month",
      "answer": "**Starter Plan** - $9/month",
      "category": "pricing",
      "subcategory": "plans",
      "chunks": [
        "We offer three pricing tiers:\n\n**Starter Plan** - $9/month\n- Up to 1,000 API calls\n- Email support\n- Basic analytics"
      ],
      "source": ["https://example.com/pricing"],
      "query_metadata": {
        "language": "en",
        "has_typos": false,
        "tone": "neutral",
        "style": "statement"
      }
    },
    {
      "query": "what features are included in the starter plan",
      "answer": "- Up to 1,000 API calls\n- Email support\n- Basic analytics",
      "category": "features_capabilities",
      "subcategory": "plans",
      "chunks": [
        "**Starter Plan** - $9/month\n- Up to 1,000 API calls\n- Email support\n- Basic analytics"
      ],
      "source": ["https://example.com/pricing"],
      "query_metadata": {
        "language": "en",
        "has_typos": false,
        "tone": "casual",
        "style": "question"
      }
    },
    {
      "query": "How many API calls can I make on the Pro Plan?",
      "answer": "Up to 10,000 API calls",
      "category": "pricing",
      "subcategory": "limits",
      "chunks": [
        "**Pro Plan** - $29/month\n- Up to 10,000 API calls\n- Priority support\n- Advanced analytics\n- Custom integrations"
      ],
      "source": ["https://example.com/pricing"],
      "query_metadata": {
        "language": "en",
        "has_typos": false,
        "tone": "neutral",
        "style": "question"
      }
    }
  ]
}

Notice: The example includes an Italian query, a long use-case description with typos, a bare phrase statement, a casual no-punctuation question, and a formal question. This is the level of diversity expected.

---

## Final Checklist

Before outputting, verify:
- [ ] All answers are exact quotes from the source
- [ ] Chunks contain the text passages where answers appear
- [ ] Categories are consistent and meaningful
- [ ] JSON is valid and properly formatted
- [ ] Source URLs/identifiers are included
- [ ] **10-15% of queries are non-English** (if generating 10+ pairs)
- [ ] **~8% of queries contain realistic typos**
- [ ] **~35% of queries are 16+ words long**
- [ ] **At least 50% of queries are NOT direct questions** (statements, commands, use cases)
- [ ] **Tone varies**: casual, formal, frustrated, and neutral are all represented
- [ ] **Some queries include formatting artifacts** (HTML entities, URLs, ALL CAPS)
- [ ] Topics are diverse — not dominated by pricing/billing
- [ ] query_metadata is accurate for each pair

---

## Output

Now generate the Q&A pairs based on the provided knowledge base content. Output ONLY valid JSON, no additional text or explanation.

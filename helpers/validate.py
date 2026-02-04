#!/usr/bin/env python3
"""
Validation helpers for synthetic data generation.
Handles exact citation matching with span computation and question deduplication.
"""

import json
import re
import sys
from difflib import SequenceMatcher
from typing import Optional


def fuzzy_match(text1: str, text2: str) -> float:
    """
    Calculate similarity ratio between two strings.
    Returns a float between 0 and 1.
    """
    if not text1 or not text2:
        return 0.0
    # Normalize whitespace and case for comparison
    t1 = ' '.join(text1.lower().split())
    t2 = ' '.join(text2.lower().split())
    return SequenceMatcher(None, t1, t2).ratio()


def compute_span(citation: str, source_content: str) -> tuple[bool, int, int]:
    """
    Find exact character position of citation in source content.

    Returns:
        (found, start_index, end_index)
    """
    if not citation or not source_content:
        return False, -1, -1

    # Try exact match first
    idx = source_content.find(citation)
    if idx >= 0:
        return True, idx, idx + len(citation)

    # Fallback: try with normalized whitespace (collapse runs of whitespace)
    normalized_citation = re.sub(r'\s+', ' ', citation.strip())
    normalized_source = re.sub(r'\s+', ' ', source_content)

    idx = normalized_source.find(normalized_citation)
    if idx >= 0:
        # Map back to original positions by counting characters
        # Walk through original source, tracking normalized position
        orig_start = -1
        orig_end = -1
        norm_pos = 0
        i = 0
        # Skip leading whitespace in source to match normalized
        while i < len(source_content):
            # Skip extra whitespace in original
            if source_content[i].isspace():
                if norm_pos > 0 and normalized_source[norm_pos - 1] == ' ':
                    i += 1
                    continue
            if norm_pos == idx and orig_start == -1:
                orig_start = i
            if norm_pos == idx + len(normalized_citation):
                orig_end = i
                break
            norm_pos += 1
            i += 1
        if orig_start >= 0 and orig_end < 0:
            orig_end = i
        if orig_start >= 0 and orig_end >= 0:
            return True, orig_start, orig_end

    return False, -1, -1


def is_duplicate_question(new_question: str, existing_questions: list[str], threshold: float = 0.95) -> tuple[bool, Optional[str], float]:
    """
    Check if a question is a duplicate of any existing question.

    Args:
        new_question: The new question to check
        existing_questions: List of existing questions
        threshold: Minimum similarity ratio to consider duplicate

    Returns:
        Tuple of (is_duplicate, matching_question, similarity_score)
    """
    if not new_question or not existing_questions:
        return False, None, 0.0

    for existing in existing_questions:
        score = fuzzy_match(new_question, existing)
        if score >= threshold:
            return True, existing, score

    return False, None, 0.0


def validate_citations(pairs: list[dict], source_content: str, existing_questions: list[str],
                       question_threshold: float = 0.95) -> dict:
    """
    Validate a list of query-citation pairs using exact matching and span computation.

    Returns dict with 'valid' and 'rejected' lists.
    """
    valid = []
    rejected = []

    # Track questions within this batch too
    batch_questions = []

    for pair in pairs:
        query = pair.get('query', '')
        citation = pair.get('citation', '')

        # Skip pairs with null citation
        if citation is None:
            rejected.append({
                **pair,
                'rejection_reason': 'citation_null',
            })
            continue

        # Validate citation exists in source with exact match
        found, start_index, end_index = compute_span(citation, source_content)

        if not found:
            rejected.append({
                **pair,
                'rejection_reason': 'citation_not_found',
            })
            continue

        # Check for duplicate question in existing output
        is_dup, dup_match, dup_score = is_duplicate_question(
            query,
            existing_questions + batch_questions,
            question_threshold
        )

        if is_dup:
            rejected.append({
                **pair,
                'rejection_reason': 'duplicate_question',
                'similarity_score': dup_score,
                'duplicate_of': dup_match
            })
            continue

        # Valid pair — add span info
        valid_pair = {**pair}
        valid_pair['start_index'] = start_index
        valid_pair['end_index'] = end_index
        valid.append(valid_pair)
        batch_questions.append(query)

    return {
        'valid': valid,
        'rejected': rejected
    }


# Keep legacy validate_pairs for backward compatibility
def validate_pairs(pairs: list[dict], source_content: str, existing_questions: list[str],
                   answer_threshold: float = 0.95, question_threshold: float = 0.95) -> dict:
    """
    Validate a list of Q&A pairs (legacy single-call format).

    Returns dict with 'valid' and 'rejected' lists.
    """
    valid = []
    rejected = []

    batch_questions = []

    for pair in pairs:
        question = pair.get('question', pair.get('query', ''))
        answer = pair.get('answer', pair.get('citation', ''))

        if not answer:
            rejected.append({
                **pair,
                'rejection_reason': 'answer_missing',
            })
            continue

        # Use exact span matching
        found, start_index, end_index = compute_span(answer, source_content)

        if not found:
            rejected.append({
                **pair,
                'rejection_reason': 'answer_mismatch',
            })
            continue

        # Check for duplicate question
        is_dup, dup_match, dup_score = is_duplicate_question(
            question,
            existing_questions + batch_questions,
            question_threshold
        )

        if is_dup:
            rejected.append({
                **pair,
                'rejection_reason': 'duplicate_question',
                'similarity_score': dup_score,
                'duplicate_of': dup_match
            })
            continue

        valid.append(pair)
        batch_questions.append(question)

    return {
        'valid': valid,
        'rejected': rejected
    }


def main():
    """
    CLI interface for validation.

    Usage:
        python validate.py validate <pairs_json> <source_content_file> <existing_questions_file>
        python validate.py validate_citations <pairs_json> <source_content_file> <existing_questions_file>
        python validate.py check_answer <answer> <source_content>
        python validate.py check_duplicate <question> <existing_questions_json>
    """
    if len(sys.argv) < 2:
        print("Usage: python validate.py <command> [args...]", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]

    if command == 'validate':
        if len(sys.argv) < 5:
            print("Usage: python validate.py validate <pairs_json> <source_file> <existing_questions_file>", file=sys.stderr)
            sys.exit(1)

        pairs = json.loads(sys.argv[2])
        with open(sys.argv[3], 'r') as f:
            source_content = f.read()
        with open(sys.argv[4], 'r') as f:
            existing_questions = json.load(f)

        result = validate_pairs(pairs, source_content, existing_questions)
        print(json.dumps(result))

    elif command == 'validate_citations':
        if len(sys.argv) < 5:
            print("Usage: python validate.py validate_citations <pairs_json> <source_file> <existing_questions_file>", file=sys.stderr)
            sys.exit(1)

        pairs = json.loads(sys.argv[2])
        with open(sys.argv[3], 'r') as f:
            source_content = f.read()
        with open(sys.argv[4], 'r') as f:
            existing_questions = json.load(f)

        result = validate_citations(pairs, source_content, existing_questions)
        print(json.dumps(result))

    elif command == 'check_answer':
        if len(sys.argv) < 4:
            print("Usage: python validate.py check_answer <answer> <source_content>", file=sys.stderr)
            sys.exit(1)

        answer = sys.argv[2]
        source_content = sys.argv[3]
        found, start, end = compute_span(answer, source_content)
        print(json.dumps({'valid': found, 'start_index': start, 'end_index': end}))

    elif command == 'check_duplicate':
        if len(sys.argv) < 4:
            print("Usage: python validate.py check_duplicate <question> <existing_questions_json>", file=sys.stderr)
            sys.exit(1)

        question = sys.argv[2]
        existing = json.loads(sys.argv[3])
        is_dup, match, score = is_duplicate_question(question, existing)
        print(json.dumps({'duplicate': is_dup, 'match': match, 'score': score}))

    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

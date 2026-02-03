#!/usr/bin/env python3
"""
Validation helpers for synthetic data generation.
Handles fuzzy matching for answer validation and question deduplication.
"""

import json
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


def find_answer_in_source(answer: str, source_content: str, threshold: float = 0.95) -> tuple[bool, float]:
    """
    Check if answer exists in source content with fuzzy matching.

    Args:
        answer: The answer text to validate
        source_content: The full source document content
        threshold: Minimum similarity ratio (default 0.95)

    Returns:
        Tuple of (is_valid, best_similarity_score)
    """
    if not answer or not source_content:
        return False, 0.0

    answer_normalized = ' '.join(answer.lower().split())
    answer_len = len(answer_normalized)

    # If exact substring match, return immediately
    if answer.lower() in source_content.lower():
        return True, 1.0

    # Sliding window approach for fuzzy matching
    source_normalized = ' '.join(source_content.lower().split())
    best_score = 0.0

    # Try different window sizes around the answer length
    for window_size in [answer_len, int(answer_len * 0.9), int(answer_len * 1.1)]:
        if window_size <= 0:
            continue
        for i in range(len(source_normalized) - window_size + 1):
            window = source_normalized[i:i + window_size]
            score = SequenceMatcher(None, answer_normalized, window).ratio()
            if score > best_score:
                best_score = score
            if score >= threshold:
                return True, score

    return best_score >= threshold, best_score


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


def validate_pairs(pairs: list[dict], source_content: str, existing_questions: list[str],
                   answer_threshold: float = 0.95, question_threshold: float = 0.95) -> dict:
    """
    Validate a list of Q&A pairs.

    Returns dict with 'valid' and 'rejected' lists.
    """
    valid = []
    rejected = []

    # Track questions within this batch too
    batch_questions = []

    for pair in pairs:
        question = pair.get('question', '')
        answer = pair.get('answer', '')

        # Validate answer exists in source
        answer_valid, answer_score = find_answer_in_source(answer, source_content, answer_threshold)

        if not answer_valid:
            rejected.append({
                **pair,
                'rejection_reason': 'answer_mismatch',
                'similarity_score': answer_score
            })
            continue

        # Check for duplicate question in existing output
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

        # Valid pair
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

    elif command == 'check_answer':
        if len(sys.argv) < 4:
            print("Usage: python validate.py check_answer <answer> <source_content>", file=sys.stderr)
            sys.exit(1)

        answer = sys.argv[2]
        source_content = sys.argv[3]
        is_valid, score = find_answer_in_source(answer, source_content)
        print(json.dumps({'valid': is_valid, 'score': score}))

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

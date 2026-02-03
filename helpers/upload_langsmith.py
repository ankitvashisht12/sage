#!/usr/bin/env python3
"""
Upload synthetic Q&A data to LangSmith as a dataset.
"""

import json
import os
import sys
from datetime import datetime

try:
    from langsmith import Client
except ImportError:
    print("Error: langsmith package not installed.")
    print("Install it with: pip install langsmith")
    sys.exit(1)


def load_jsonl(filepath: str) -> list[dict]:
    """Load data from a JSONL file."""
    data = []
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                data.append(json.loads(line))
    return data


def upload_to_langsmith(
    data: list[dict],
    dataset_name: str,
    description: str = None
) -> str:
    """
    Upload Q&A pairs to LangSmith as a dataset.

    Args:
        data: List of Q&A pair dictionaries
        dataset_name: Name for the dataset
        description: Optional description

    Returns:
        Dataset URL
    """
    client = Client()

    # Create or get existing dataset
    try:
        dataset = client.create_dataset(
            dataset_name=dataset_name,
            description=description or f"Synthetic Q&A dataset generated on {datetime.now().isoformat()}"
        )
        print(f"Created new dataset: {dataset_name}")
    except Exception as e:
        if "already exists" in str(e).lower():
            # Get existing dataset
            datasets = list(client.list_datasets(dataset_name=dataset_name))
            if datasets:
                dataset = datasets[0]
                print(f"Using existing dataset: {dataset_name}")
            else:
                raise e
        else:
            raise e

    # Add examples to dataset
    examples_created = 0
    for item in data:
        try:
            # Structure for RAG evaluation
            inputs = {
                "question": item.get("question", ""),
            }

            outputs = {
                "answer": item.get("answer", ""),
                "chunks": item.get("chunks", []),
                "source": item.get("source", []),
            }

            metadata = {
                "category": item.get("category", ""),
                "subcategory": item.get("subcategory", ""),
            }

            client.create_example(
                inputs=inputs,
                outputs=outputs,
                metadata=metadata,
                dataset_id=dataset.id
            )
            examples_created += 1
        except Exception as e:
            print(f"Warning: Failed to create example: {e}")
            continue

    print(f"Created {examples_created} examples in dataset")

    # Get dataset URL
    # LangSmith URL format: https://smith.langchain.com/datasets/{dataset_id}
    endpoint = os.getenv("LANGSMITH_ENDPOINT", "https://smith.langchain.com")
    # Remove /api if present
    base_url = endpoint.replace("/api", "").replace("api.", "")
    if "smith.langchain.com" not in base_url:
        base_url = "https://smith.langchain.com"

    dataset_url = f"{base_url}/datasets/{dataset.id}"

    return dataset_url


def main():
    """
    CLI interface for uploading to LangSmith.

    Usage:
        python upload_langsmith.py <input_file> [dataset_name]
    """
    if len(sys.argv) < 2:
        print("Usage: python upload_langsmith.py <input_file> [dataset_name]")
        print("")
        print("Environment variables required:")
        print("  LANGSMITH_API_KEY - Your LangSmith API key")
        print("")
        print("Optional environment variables:")
        print("  LANGSMITH_ENDPOINT - API endpoint (default: https://api.smith.langchain.com)")
        print("  LANGSMITH_DATASET_NAME - Default dataset name")
        sys.exit(1)

    input_file = sys.argv[1]

    # Get dataset name from args or env
    dataset_name = sys.argv[2] if len(sys.argv) > 2 else os.getenv("LANGSMITH_DATASET_NAME", "rag-eval-dataset")

    # Check for API key
    if not os.getenv("LANGSMITH_API_KEY"):
        print("Error: LANGSMITH_API_KEY environment variable not set")
        print("Get your API key from: https://smith.langchain.com/settings")
        sys.exit(1)

    # Load data
    if not os.path.exists(input_file):
        print(f"Error: File not found: {input_file}")
        sys.exit(1)

    print(f"Loading data from: {input_file}")
    data = load_jsonl(input_file)
    print(f"Loaded {len(data)} Q&A pairs")

    if not data:
        print("Error: No data to upload")
        sys.exit(1)

    # Upload to LangSmith
    print(f"\nUploading to LangSmith dataset: {dataset_name}")
    print("-" * 50)

    try:
        dataset_url = upload_to_langsmith(data, dataset_name)
        print("-" * 50)
        print(f"\n✓ Upload complete!")
        print(f"\nDataset URL: {dataset_url}")
    except Exception as e:
        print(f"\n✗ Upload failed: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()

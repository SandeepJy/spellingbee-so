#!/usr/bin/env python3
"""
Script to check new words from newwords.txt against dictionary API
and append words with phonetics-audio URLs to hard_words_with_audio.txt
if they're not already in the list.
"""

import requests
import time
import os
from typing import Optional, Set, Tuple

API_BASE_URL = "https://api.dictionaryapi.dev/api/v2/entries/en/"
DELAY_SECONDS = 1.5  # Delay between requests to avoid overwhelming the API


def check_word_has_audio(word: str) -> Optional[str]:
    """
    Check if a word has a phonetics-audio URL in the API response.
    Returns the word if it has audio, None otherwise.
    """
    try:
        url = f"{API_BASE_URL}{word}"
        response = requests.get(url, timeout=10)

        if response.status_code == 200:
            data = response.json()
            if isinstance(data, list) and len(data) > 0:
                entry = data[0]
                if "phonetics" in entry:
                    phonetics = entry["phonetics"]
                    for phonetic in phonetics:
                        if "audio" in phonetic and phonetic["audio"]:
                            return word
        elif response.status_code == 404:
            # Word not found
            return None
        else:
            print(f"Warning: Status {response.status_code} for word '{word}'")
            return None

    except requests.exceptions.RequestException as e:
        print(f"Error checking '{word}': {e}")
        return None
    except Exception as e:
        print(f"Unexpected error for '{word}': {e}")
        return None


def read_existing_words(filename: str) -> Tuple[Set[str], int]:
    """
    Read existing words from hard_words_with_audio.txt (comma-delimited)
    Returns a tuple of (set of lowercase words, count of existing words).
    """
    existing_words = set()
    count = 0

    if not os.path.exists(filename):
        print(f"File {filename} does not exist. Will create it.")
        return existing_words, count

    try:
        with open(filename, "r") as f:
            content = f.read().strip()
            if content:
                # Split by comma and clean up whitespace
                words = [w.strip().lower() for w in content.split(",") if w.strip()]
                existing_words = set(words)
                count = len(words)
                print(f"Found {count} existing words in {filename}")
    except Exception as e:
        print(f"Error reading {filename}: {e}")

    return existing_words, count


def read_new_words(filename: str) -> list:
    """
    Read new words from newwords.txt (comma-delimited)
    Returns a list of words.
    """
    if not os.path.exists(filename):
        print(f"Error: {filename} does not exist!")
        return []

    try:
        with open(filename, "r") as f:
            content = f.read().strip()
            # Split by comma and clean up whitespace
            words = [w.strip().lower() for w in content.split(",") if w.strip()]
            print(f"Read {len(words)} words from {filename}")
            return words
    except Exception as e:
        print(f"Error reading {filename}: {e}")
        return []


def append_to_file(filename: str, new_words: list, existing_count: int):
    """
    Append new words to hard_words_with_audio.txt (comma-delimited format)
    """
    if not new_words:
        print("No new words to append.")
        return

    try:
        if os.path.exists(filename):
            # Read existing content
            with open(filename, "r") as f:
                content = f.read().strip()

            # Parse existing words
            existing_words_list = []
            if content:
                existing_words_list = [
                    w.strip() for w in content.split(",") if w.strip()
                ]

            # Add new words
            existing_words_list.extend(new_words)

            # Write back as comma-delimited
            with open(filename, "w") as f:
                f.write(", ".join(existing_words_list))
        else:
            # Create new file
            with open(filename, "w") as f:
                f.write(", ".join(new_words))

        new_count = existing_count + len(new_words)
        print(f"\nAppended {len(new_words)} new words to {filename}")
        print(f"Total words in file: {new_count}")
    except Exception as e:
        print(f"Error appending to {filename}: {e}")


def main():
    """Main function to check new words and append to existing list."""
    new_words_file = "newwords.txt"
    existing_file = "hard_words_with_audio.txt"

    # Read existing words
    existing_words, existing_count = read_existing_words(existing_file)

    # Read new words
    new_words = read_new_words(new_words_file)

    if not new_words:
        print("No new words to process.")
        return

    # Filter out words already in the existing list
    words_to_check = [w for w in new_words if w.lower() not in existing_words]

    if not words_to_check:
        print("All words are already in the existing list.")
        return

    print(f"\nChecking {len(words_to_check)} new words (after removing duplicates)...")
    print(f"Delay between requests: {DELAY_SECONDS} seconds")
    print("-" * 60)

    # Check each word for audio
    words_with_audio = []
    for i, word in enumerate(words_to_check, 1):
        print(f"[{i}/{len(words_to_check)}] Checking: {word}", end=" ... ")

        result = check_word_has_audio(word)

        if result:
            words_with_audio.append(result)
            print(f"✓ HAS AUDIO ({len(words_with_audio)} found so far)")
        else:
            print("✗ no audio")

        # Delay to avoid overwhelming the API
        if i < len(words_to_check):
            time.sleep(DELAY_SECONDS)

    print("-" * 60)
    print(f"\nTotal new words checked: {len(words_to_check)}")
    print(f"New words with audio found: {len(words_with_audio)}")

    # Append new words to file
    if words_with_audio:
        append_to_file(existing_file, words_with_audio, existing_count)
        print(
            f"\nSuccessfully added {len(words_with_audio)} new words to {existing_file}"
        )
    else:
        print("\nNo new words with audio to add.")


if __name__ == "__main__":
    main()

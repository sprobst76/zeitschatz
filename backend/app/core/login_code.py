"""Login code generator for child-friendly authentication codes.

Generates codes in format: TIER-FARBE-NN (e.g., TIGER-BLAU-42)
"""

import random
import secrets
from typing import Optional

# German animal names (child-friendly, easy to spell)
ANIMALS = [
    "ADLER", "BAER", "DELFIN", "DRACHE", "ELEFANT", "EULE", "FUCHS", "GIRAFFE",
    "HASE", "HUND", "IGEL", "KATZE", "KOALA", "LOEWE", "MAUS", "OTTER",
    "PANDA", "PAPAGEI", "PFERD", "PINGUIN", "RABE", "TIGER", "VOGEL", "WOLF",
    "ZEBRA", "AFFE", "BIBER", "DACHS", "FALKE", "FROSCH", "HAMSTER", "HIRSCH",
    "KROKODIL", "LACHS", "MARDER", "NASHORN", "ORCA", "RATTE", "SCHWAN", "SPINNE",
]

# German colors (easy to spell)
COLORS = [
    "BLAU", "GELB", "GRUEN", "ROT", "ORANGE", "LILA", "ROSA", "BRAUN",
    "WEISS", "SCHWARZ", "GOLD", "SILBER", "TUERKIS", "PINK", "GRAU", "VIOLETT",
]

# German adjectives (positive, child-friendly)
ADJECTIVES = [
    "SUPER", "COOL", "STARK", "SCHNELL", "KLUG", "MUTIG", "LUSTIG", "WILD",
    "SANFT", "GROSS", "KLEIN", "FRECH", "SCHLAU", "TAPFER", "FLOTT", "FIX",
]


def generate_login_code(style: str = "animal-color") -> str:
    """Generate a unique, readable login code.

    Args:
        style: Code style - "animal-color" (default), "animal-adjective", or "adjective-animal"

    Returns:
        A code like "TIGER-BLAU-42"
    """
    number = secrets.randbelow(90) + 10  # 10-99

    if style == "animal-adjective":
        word1 = secrets.choice(ANIMALS)
        word2 = secrets.choice(ADJECTIVES)
    elif style == "adjective-animal":
        word1 = secrets.choice(ADJECTIVES)
        word2 = secrets.choice(ANIMALS)
    else:  # animal-color (default)
        word1 = secrets.choice(ANIMALS)
        word2 = secrets.choice(COLORS)

    return f"{word1}-{word2}-{number}"


def generate_unique_code(existing_codes: set[str], max_attempts: int = 100) -> Optional[str]:
    """Generate a code that doesn't exist in the given set.

    Args:
        existing_codes: Set of already used codes
        max_attempts: Maximum generation attempts before giving up

    Returns:
        A unique code, or None if couldn't generate one
    """
    for _ in range(max_attempts):
        code = generate_login_code()
        if code not in existing_codes:
            return code
    return None


def normalize_code(code: str) -> str:
    """Normalize a code for comparison (uppercase, trimmed)."""
    return code.strip().upper()


def is_valid_code_format(code: str) -> bool:
    """Check if a code has valid format (WORD-WORD-NN)."""
    parts = code.split("-")
    if len(parts) != 3:
        return False

    word1, word2, number = parts

    # Check words are alphabetic
    if not word1.isalpha() or not word2.isalpha():
        return False

    # Check number is 2 digits
    if not number.isdigit() or len(number) != 2:
        return False

    return True

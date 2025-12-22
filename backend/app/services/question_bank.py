"""Question bank for learning exercises."""
import random
from typing import List, Dict, Any

# Subject definitions
SUBJECTS = {
    "math": {"name": "Mathe", "icon": "calculate"},
    "english": {"name": "Englisch", "icon": "translate"},
    "german": {"name": "Deutsch", "icon": "menu_book"},
}

# Difficulty levels
DIFFICULTIES = {
    "grade1": {"name": "Klasse 1", "min_age": 6, "reward_minutes": 5},
    "grade2": {"name": "Klasse 2", "min_age": 7, "reward_minutes": 7},
    "grade3": {"name": "Klasse 3", "min_age": 8, "reward_minutes": 10},
    "grade4": {"name": "Klasse 4", "min_age": 9, "reward_minutes": 12},
    "grade5plus": {"name": "Klasse 5+", "min_age": 10, "reward_minutes": 15},
}


def generate_math_question(difficulty: str) -> Dict[str, Any]:
    """Generate a random math question based on difficulty."""
    if difficulty == "grade1":
        # Addition/Subtraction up to 20
        op = random.choice(["+", "-"])
        if op == "+":
            a = random.randint(1, 10)
            b = random.randint(1, 10)
            answer = a + b
        else:
            a = random.randint(5, 20)
            b = random.randint(1, a)
            answer = a - b
        return {
            "type": "calculation",
            "question": f"{a} {op} {b} = ?",
            "answer": str(answer),
            "hint": None,
        }

    elif difficulty == "grade2":
        # Addition/Subtraction up to 100, simple multiplication
        op = random.choice(["+", "-", "×"])
        if op == "+":
            a = random.randint(10, 50)
            b = random.randint(10, 50)
            answer = a + b
        elif op == "-":
            a = random.randint(30, 100)
            b = random.randint(10, a)
            answer = a - b
        else:
            a = random.randint(2, 5)
            b = random.randint(2, 5)
            answer = a * b
        return {
            "type": "calculation",
            "question": f"{a} {op} {b} = ?",
            "answer": str(answer),
            "hint": None,
        }

    elif difficulty == "grade3":
        # Multiplication table, division
        op = random.choice(["×", "×", "÷"])
        if op == "×":
            a = random.randint(2, 10)
            b = random.randint(2, 10)
            answer = a * b
            return {
                "type": "calculation",
                "question": f"{a} × {b} = ?",
                "answer": str(answer),
                "hint": f"Einmaleins mit {a}",
            }
        else:
            b = random.randint(2, 10)
            answer = random.randint(2, 10)
            a = b * answer
            return {
                "type": "calculation",
                "question": f"{a} ÷ {b} = ?",
                "answer": str(answer),
                "hint": "Denke an das Einmaleins",
            }

    elif difficulty == "grade4":
        # Larger numbers, mixed operations
        op = random.choice(["+", "-", "×", "÷"])
        if op == "+":
            a = random.randint(100, 500)
            b = random.randint(100, 500)
            answer = a + b
        elif op == "-":
            a = random.randint(200, 1000)
            b = random.randint(100, a)
            answer = a - b
        elif op == "×":
            a = random.randint(10, 25)
            b = random.randint(2, 10)
            answer = a * b
        else:
            b = random.randint(2, 12)
            answer = random.randint(5, 20)
            a = b * answer
        return {
            "type": "calculation",
            "question": f"{a} {op} {b} = ?",
            "answer": str(answer),
            "hint": None,
        }

    else:  # grade5plus
        # More complex calculations
        question_type = random.choice(["calc", "percent", "fraction"])
        if question_type == "calc":
            a = random.randint(50, 200)
            b = random.randint(10, 50)
            c = random.randint(2, 10)
            answer = a + b * c
            return {
                "type": "calculation",
                "question": f"{a} + {b} × {c} = ?",
                "answer": str(answer),
                "hint": "Punkt vor Strich!",
            }
        elif question_type == "percent":
            base = random.choice([50, 100, 200, 500])
            percent = random.choice([10, 20, 25, 50])
            answer = base * percent // 100
            return {
                "type": "calculation",
                "question": f"{percent}% von {base} = ?",
                "answer": str(answer),
                "hint": f"{percent}% = {percent}/100",
            }
        else:
            a = random.randint(2, 10)
            b = random.randint(2, 10)
            c = random.randint(2, 10)
            d = random.randint(2, 10)
            # Simple fraction addition with same denominator
            denom = random.choice([2, 4, 5, 10])
            num1 = random.randint(1, denom - 1)
            num2 = random.randint(1, denom - num1)
            answer = num1 + num2
            return {
                "type": "calculation",
                "question": f"{num1}/{denom} + {num2}/{denom} = ?/{denom}",
                "answer": str(answer),
                "hint": "Zaehler addieren, Nenner bleibt gleich",
            }


# English vocabulary by difficulty
ENGLISH_VOCAB = {
    "grade1": [
        ("cat", "Katze"), ("dog", "Hund"), ("house", "Haus"), ("tree", "Baum"),
        ("sun", "Sonne"), ("moon", "Mond"), ("star", "Stern"), ("water", "Wasser"),
        ("bread", "Brot"), ("milk", "Milch"), ("apple", "Apfel"), ("ball", "Ball"),
        ("book", "Buch"), ("pen", "Stift"), ("door", "Tuer"), ("car", "Auto"),
        ("red", "rot"), ("blue", "blau"), ("green", "gruen"), ("yellow", "gelb"),
    ],
    "grade2": [
        ("mother", "Mutter"), ("father", "Vater"), ("sister", "Schwester"), ("brother", "Bruder"),
        ("school", "Schule"), ("teacher", "Lehrer"), ("friend", "Freund"), ("happy", "gluecklich"),
        ("sad", "traurig"), ("big", "gross"), ("small", "klein"), ("new", "neu"),
        ("old", "alt"), ("good", "gut"), ("bad", "schlecht"), ("beautiful", "schoen"),
        ("Monday", "Montag"), ("Tuesday", "Dienstag"), ("summer", "Sommer"), ("winter", "Winter"),
    ],
    "grade3": [
        ("breakfast", "Fruehstueck"), ("lunch", "Mittagessen"), ("dinner", "Abendessen"),
        ("homework", "Hausaufgaben"), ("bicycle", "Fahrrad"), ("airplane", "Flugzeug"),
        ("mountain", "Berg"), ("river", "Fluss"), ("forest", "Wald"), ("animal", "Tier"),
        ("weather", "Wetter"), ("holiday", "Urlaub"), ("birthday", "Geburtstag"),
        ("tomorrow", "morgen"), ("yesterday", "gestern"), ("always", "immer"),
        ("never", "nie"), ("sometimes", "manchmal"), ("often", "oft"), ("usually", "normalerweise"),
    ],
    "grade4": [
        ("difficult", "schwierig"), ("easy", "einfach"), ("important", "wichtig"),
        ("interesting", "interessant"), ("boring", "langweilig"), ("dangerous", "gefaehrlich"),
        ("comfortable", "bequem"), ("expensive", "teuer"), ("cheap", "billig"),
        ("environment", "Umwelt"), ("science", "Wissenschaft"), ("history", "Geschichte"),
        ("geography", "Erdkunde"), ("language", "Sprache"), ("example", "Beispiel"),
        ("question", "Frage"), ("answer", "Antwort"), ("problem", "Problem"),
        ("solution", "Loesung"), ("difference", "Unterschied"),
    ],
    "grade5plus": [
        ("achievement", "Leistung"), ("advertisement", "Werbung"), ("although", "obwohl"),
        ("appearance", "Erscheinung"), ("available", "verfuegbar"), ("behaviour", "Verhalten"),
        ("competition", "Wettbewerb"), ("consequence", "Konsequenz"), ("development", "Entwicklung"),
        ("disappointed", "enttaeuscht"), ("embarrassed", "verlegen"), ("entertainment", "Unterhaltung"),
        ("environment", "Umwelt"), ("eventually", "schliesslich"), ("experience", "Erfahrung"),
        ("government", "Regierung"), ("immediately", "sofort"), ("independent", "unabhaengig"),
        ("necessary", "notwendig"), ("opportunity", "Gelegenheit"),
    ],
}


def generate_english_question(difficulty: str) -> Dict[str, Any]:
    """Generate an English vocabulary question."""
    vocab = ENGLISH_VOCAB.get(difficulty, ENGLISH_VOCAB["grade3"])
    english, german = random.choice(vocab)

    # Randomly ask English->German or German->English
    if random.random() < 0.5:
        return {
            "type": "translation",
            "question": f"Was heisst '{english}' auf Deutsch?",
            "answer": german.lower(),
            "hint": f"Anfangsbuchstabe: {german[0].upper()}",
            "accept_alternatives": [german.lower(), german.capitalize()],
        }
    else:
        return {
            "type": "translation",
            "question": f"Was heisst '{german}' auf Englisch?",
            "answer": english.lower(),
            "hint": f"Anfangsbuchstabe: {english[0].upper()}",
            "accept_alternatives": [english.lower(), english.capitalize()],
        }


# German exercises
GERMAN_EXERCISES = {
    "grade1": {
        "spelling": [
            ("Hund", "H_nd"), ("Katze", "K_tze"), ("Baum", "B__m"), ("Haus", "H__s"),
            ("Sonne", "S_nne"), ("Blume", "Bl_me"), ("Vogel", "V_gel"), ("Fisch", "F_sch"),
        ],
    },
    "grade2": {
        "spelling": [
            ("Schule", "Sch_le"), ("Freund", "Fre_nd"), ("spielen", "sp_elen"),
            ("schreiben", "schr_iben"), ("Wasser", "Wa_er"), ("Himmel", "Hi_el"),
        ],
        "articles": [
            ("Hund", "der"), ("Katze", "die"), ("Haus", "das"), ("Baum", "der"),
            ("Blume", "die"), ("Auto", "das"), ("Schule", "die"), ("Buch", "das"),
        ],
    },
    "grade3": {
        "articles": [
            ("Computer", "der"), ("Telefon", "das"), ("Tasche", "die"),
            ("Fenster", "das"), ("Tisch", "der"), ("Lampe", "die"),
            ("Stuhl", "der"), ("Bett", "das"), ("Uhr", "die"),
        ],
        "plural": [
            ("Hund", "Hunde"), ("Katze", "Katzen"), ("Haus", "Haeuser"),
            ("Baum", "Baeume"), ("Kind", "Kinder"), ("Buch", "Buecher"),
        ],
    },
    "grade4": {
        "cases": [
            ("Der Hund beisst ___ Mann.", "den", "Akkusativ"),
            ("Ich gebe ___ Kind einen Apfel.", "dem", "Dativ"),
            ("Das ist das Auto ___ Lehrers.", "des", "Genitiv"),
            ("___ Katze schlaeft.", "Die", "Nominativ"),
        ],
        "verbs": [
            ("laufen - er ___", "laeuft"), ("sehen - sie ___", "sieht"),
            ("lesen - er ___", "liest"), ("fahren - sie ___", "faehrt"),
        ],
    },
    "grade5plus": {
        "cases": [
            ("Wegen ___ Regens bleiben wir zu Hause.", "des", "Genitiv"),
            ("Er hilft ___ alten Frau.", "der", "Dativ"),
            ("Ich sehe ___ grossen Hund.", "den", "Akkusativ"),
            ("Trotz ___ Kaelte gehen wir spazieren.", "der", "Genitiv"),
        ],
        "conjunctions": [
            ("Er kommt nicht, ___ er krank ist.", "weil"),
            ("Ich weiss nicht, ___ er kommt.", "ob"),
            ("Sie liest, ___ sie muss lernen.", "obwohl"),
        ],
    },
}


def generate_german_question(difficulty: str) -> Dict[str, Any]:
    """Generate a German language question."""
    exercises = GERMAN_EXERCISES.get(difficulty, GERMAN_EXERCISES["grade3"])

    exercise_type = random.choice(list(exercises.keys()))
    items = exercises[exercise_type]
    item = random.choice(items)

    if exercise_type == "spelling":
        word, pattern = item
        return {
            "type": "spelling",
            "question": f"Ergaenze: {pattern}",
            "answer": word.lower(),
            "hint": f"Das Wort hat {len(word)} Buchstaben",
            "accept_alternatives": [word.lower(), word.capitalize()],
        }
    elif exercise_type == "articles":
        noun, article = item
        return {
            "type": "article",
            "question": f"Welcher Artikel? ___ {noun}",
            "answer": article,
            "hint": "der, die oder das?",
            "accept_alternatives": [article, article.capitalize()],
        }
    elif exercise_type == "plural":
        singular, plural = item
        return {
            "type": "plural",
            "question": f"Mehrzahl von '{singular}'?",
            "answer": plural.lower(),
            "hint": f"Anfangsbuchstabe: {plural[0]}",
            "accept_alternatives": [plural.lower(), plural.capitalize()],
        }
    elif exercise_type == "cases":
        sentence, answer, case = item
        return {
            "type": "case",
            "question": sentence,
            "answer": answer.lower(),
            "hint": f"Fall: {case}",
            "accept_alternatives": [answer.lower(), answer.capitalize()],
        }
    elif exercise_type == "verbs":
        pattern, answer = item
        return {
            "type": "verb",
            "question": pattern,
            "answer": answer.lower(),
            "hint": "Konjugiere das Verb",
            "accept_alternatives": [answer.lower(), answer.capitalize()],
        }
    elif exercise_type == "conjunctions":
        sentence, answer = item
        return {
            "type": "conjunction",
            "question": sentence,
            "answer": answer.lower(),
            "hint": "Welches Bindewort passt?",
            "accept_alternatives": [answer.lower(), answer.capitalize()],
        }

    # Fallback
    return generate_german_question("grade2")


def get_question(subject: str, difficulty: str) -> Dict[str, Any]:
    """Get a random question for the given subject and difficulty."""
    if subject == "math":
        return generate_math_question(difficulty)
    elif subject == "english":
        return generate_english_question(difficulty)
    elif subject == "german":
        return generate_german_question(difficulty)
    else:
        raise ValueError(f"Unknown subject: {subject}")


def check_answer(question: Dict[str, Any], user_answer: str) -> bool:
    """Check if the user's answer is correct."""
    user_answer = user_answer.strip().lower()
    correct_answer = question["answer"].strip().lower()

    if user_answer == correct_answer:
        return True

    # Check alternatives
    alternatives = question.get("accept_alternatives", [])
    for alt in alternatives:
        if user_answer == alt.strip().lower():
            return True

    return False


def get_questions(subject: str, difficulty: str, count: int = 10) -> List[Dict[str, Any]]:
    """Get multiple questions for a learning session."""
    return [get_question(subject, difficulty) for _ in range(count)]

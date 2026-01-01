"""Heuristic validator for Eldertide Armament status/passive/spell references."""
import pathlib
import re

# Set to your mod's stats folder
MOD_DIR = pathlib.Path("Public/EldertideArmament/Stats/Generated/Data")

# Optional: AI-Allies (Overhaul) reference dump (placed under reference/)
AI_ALLIES_DIR = pathlib.Path(
    "reference/AI-Allies (Overhaul)/Public/AI Allies/Stats/Generated/Data"
)

REF_BASE = pathlib.Path("reference/vanilla_data/Gustav/Stats/Generated/Data")
REF_STATUS = REF_BASE / "Status_BOOST.txt"
REF_PASSIVE = REF_BASE / "Passive.txt"
REF_SPELLS = [REF_BASE / "Spell_Target.txt", REF_BASE / "Spell_Projectile.txt"]

CUSTOM_STATUS = [MOD_DIR / "Status_Eldertide.txt"]
CUSTOM_PASSIVE = [MOD_DIR / "Passive_Eldertide.txt"]
CUSTOM_SPELLS = [
    MOD_DIR / "Spell_Rush.txt",
    MOD_DIR / "Spell_Shout.txt",
    MOD_DIR / "Spell_Target.txt",
    MOD_DIR / "Spell_Zone.txt",
    MOD_DIR / "Spells_Eldertide_Companions.txt",
    MOD_DIR / "Spells_Eldertide_Interrupt.txt",
    MOD_DIR / "Spells_Eldertide_Main.txt",
]
SCAN_FILES = list(
    {
        *CUSTOM_STATUS,
        *CUSTOM_PASSIVE,
        *CUSTOM_SPELLS,
        MOD_DIR / "Armor.txt",
        MOD_DIR / "Character.txt",
        MOD_DIR / "Interrupt.txt",
        MOD_DIR / "Object.txt",
        MOD_DIR / "Potions_Eldertide.txt",
        MOD_DIR / "Weapon.txt",
    }
)

AI_STATUS = [AI_ALLIES_DIR / "Statuses.txt", AI_ALLIES_DIR / "Statuses - Controller.txt"]
AI_PASSIVE = [AI_ALLIES_DIR / "PassiveComp.txt"]
AI_SPELLS = [
    AI_ALLIES_DIR / "Ally_Spells.txt",
    AI_ALLIES_DIR / "Spells_For_AI.txt",
]


def entries(path: pathlib.Path) -> set[str]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except FileNotFoundError:
        return set()
    return {m.group(1) for m in re.finditer(r'new entry "([^"]+)"', text)}


def referenced_tokens(text: str) -> set[str]:
    tokens: set[str] = set()
    for functor in ("ApplyStatus", "HasStatus", "RemoveStatus"):
        tokens.update(re.findall(rf"{functor}\(\s*([A-Za-z0-9_]+)", text))
    tokens.update(re.findall(r"UnlockSpell\(\s*([A-Za-z0-9_]+)", text))
    return {t for t in tokens if t.upper() == t}


def collect_refs() -> set[str]:
    refs: set[str] = set()
    for path in SCAN_FILES:
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except FileNotFoundError:
            continue
        for tok in referenced_tokens(text):
            refs.add(tok)
    return refs


def main() -> None:
    ref_status = entries(REF_STATUS)
    ref_passive = entries(REF_PASSIVE)
    ref_spells = set().union(*(entries(p) for p in REF_SPELLS))

    custom_status = set().union(*(entries(p) for p in CUSTOM_STATUS))
    custom_passive = set().union(*(entries(p) for p in CUSTOM_PASSIVE))
    custom_spells = set().union(*(entries(p) for p in CUSTOM_SPELLS))

    ai_status = set().union(*(entries(p) for p in AI_STATUS))
    ai_passive = set().union(*(entries(p) for p in AI_PASSIVE))
    ai_spells = set().union(*(entries(p) for p in AI_SPELLS))

    noise = {"ALLIES_AI_1", "ALLIES_AI_2", "ALLIES_CONTROLLED", "ALLIES_ORDER"}

    refs = {tok for tok in collect_refs() if tok not in noise}

    available_status = custom_status | ai_status
    available_passive = custom_passive | ai_passive
    available_spells = custom_spells | ai_spells

    missing_status = {
        r
        for r in refs
        if r in ref_status or r.startswith("AI_ALLIES") or r.startswith("ALLIES")
    } - available_status
    missing_passive = {r for r in refs if r in ref_passive} - available_passive
    missing_spell = {r for r in refs if r in ref_spells} - available_spells

    colliding_status = custom_status & ai_status
    colliding_passive = custom_passive & ai_passive
    colliding_spell = custom_spells & ai_spells

    had_issue = False
    if missing_status:
        print("Missing status definitions:")
        for r in sorted(missing_status):
            print("  ", r)
        had_issue = True
    if missing_passive:
        print("Missing passive definitions:")
        for r in sorted(missing_passive):
            print("  ", r)
        had_issue = True
    if missing_spell:
        print("Missing spell definitions:")
        for r in sorted(missing_spell):
            print("  ", r)
        had_issue = True

    if colliding_status:
        print("Collision: Eldertide status IDs also present in AI-Allies dump:")
        for r in sorted(colliding_status):
            print("  ", r)
        had_issue = True
    if colliding_passive:
        print("Collision: Eldertide passive IDs also present in AI-Allies dump:")
        for r in sorted(colliding_passive):
            print("  ", r)
        had_issue = True
    if colliding_spell:
        print("Collision: Eldertide spell IDs also present in AI-Allies dump:")
        for r in sorted(colliding_spell):
            print("  ", r)
        had_issue = True

    if not had_issue:
        print("OK: no missing status/passive/spell IDs found by heuristic scan.")


if __name__ == "__main__":
    main()

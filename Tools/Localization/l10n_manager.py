#!/usr/bin/env python3
"""
Localization Manager for Localizable.xcstrings

Manages localization strings in Xcode String Catalog format.
Supports: add, get, list, check, update commands.
"""

import json
import argparse
import sys
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Supported languages
SUPPORTED_LANGUAGES = ['en', 'es', 'fr', 'de', 'it', 'pt']
XCSTRINGS_PATH = Path("PrestoCV/Localizable.xcstrings")


class L10nManager:
    """Manager for Localizable.xcstrings operations"""

    def __init__(self, xcstrings_path: Path = XCSTRINGS_PATH):
        self.xcstrings_path = xcstrings_path
        self.data: Optional[Dict] = None

    def load(self) -> bool:
        """Load the xcstrings file"""
        try:
            if not self.xcstrings_path.exists():
                print(f"Error: {self.xcstrings_path} not found", file=sys.stderr)
                return False

            with open(self.xcstrings_path, 'r', encoding='utf-8') as f:
                self.data = json.load(f)
            return True
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON: {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Error loading file: {e}", file=sys.stderr)
            return False

    def save(self) -> bool:
        """Save the xcstrings file with proper formatting"""
        try:
            with open(self.xcstrings_path, 'w', encoding='utf-8') as f:
                json.dump(self.data, f, ensure_ascii=False, indent=2)
                f.write('\n')  # Add trailing newline
            return True
        except Exception as e:
            print(f"Error saving file: {e}", file=sys.stderr)
            return False

    def add_key(self, key: str, translations: Dict[str, str]) -> bool:
        """Add a new localization key with translations"""
        if not self.data:
            return False

        # Check if key already exists
        if key in self.data.get('strings', {}):
            print(f"Error: Key '{key}' already exists. Use 'update' to modify.", file=sys.stderr)
            return False

        # Validate all languages are provided
        missing_langs = set(SUPPORTED_LANGUAGES) - set(translations.keys())
        if missing_langs:
            print(f"Error: Missing translations for: {', '.join(sorted(missing_langs))}", file=sys.stderr)
            return False

        # Create the key entry
        localizations = {}
        for lang in SUPPORTED_LANGUAGES:
            localizations[lang] = {
                "stringUnit": {
                    "state": "translated",
                    "value": translations[lang]
                }
            }

        entry = {
            "extractionState": "manual",
            "localizations": localizations
        }

        # Add to strings
        if 'strings' not in self.data:
            self.data['strings'] = {}

        self.data['strings'][key] = entry
        print(f"✅ Added key: {key}")
        return True

    def get_key(self, key: str) -> Optional[Dict[str, str]]:
        """Get translations for a key"""
        if not self.data:
            return None

        strings = self.data.get('strings', {})
        if key not in strings:
            print(f"Error: Key '{key}' not found", file=sys.stderr)
            return None

        entry = strings[key]
        localizations = entry.get('localizations', {})

        # Check if localizations is empty
        if not localizations:
            print(f"Error: Key '{key}' has no translations (empty entry)", file=sys.stderr)
            return None

        translations = {}
        for lang in SUPPORTED_LANGUAGES:
            if lang in localizations:
                translations[lang] = localizations[lang].get('stringUnit', {}).get('value', '')

        return translations

    def list_keys(self, filter_pattern: Optional[str] = None) -> List[Tuple[str, str]]:
        """List all keys (optionally filtered)"""
        if not self.data:
            return []

        strings = self.data.get('strings', {})
        results = []

        for key in sorted(strings.keys()):
            if filter_pattern and filter_pattern not in key:
                continue

            # Get English value as preview
            localizations = strings[key].get('localizations', {})
            en_value = localizations.get('en', {}).get('stringUnit', {}).get('value', '')
            results.append((key, en_value))

        return results

    def update_key(self, key: str, lang: str, value: str) -> bool:
        """Update a translation for a specific language"""
        if not self.data:
            return False

        strings = self.data.get('strings', {})
        if key not in strings:
            print(f"Error: Key '{key}' not found", file=sys.stderr)
            return False

        if lang not in SUPPORTED_LANGUAGES:
            print(f"Error: Unsupported language '{lang}'. Supported: {', '.join(SUPPORTED_LANGUAGES)}", file=sys.stderr)
            return False

        # Update the translation
        entry = strings[key]
        if 'localizations' not in entry:
            entry['localizations'] = {}

        if lang not in entry['localizations']:
            entry['localizations'][lang] = {}

        entry['localizations'][lang]['stringUnit'] = {
            "state": "translated",
            "value": value
        }

        print(f"✅ Updated {lang} translation for key: {key}")
        return True

    def check_hardcoded_strings(self, path: str) -> List[Tuple[str, int, str]]:
        """Find hardcoded strings in Swift files"""
        results = []
        path_obj = Path(path)

        if not path_obj.exists():
            print(f"Error: Path '{path}' not found", file=sys.stderr)
            return results

        # Find all Swift files
        if path_obj.is_file():
            swift_files = [path_obj] if path_obj.suffix == '.swift' else []
        else:
            swift_files = list(path_obj.rglob('*.swift'))

        # Pattern to find string literals
        # Matches: "text" or """text""" but not String(localized:) or LocalizedStringKey
        string_pattern = re.compile(r'(?<!String\(localized:\s)(?<!LocalizedStringKey\()(?<!\.localized\s)"([^"\\]*(\\.[^"\\]*)*)"')

        for swift_file in swift_files:
            try:
                with open(swift_file, 'r', encoding='utf-8') as f:
                    for line_num, line in enumerate(f, 1):
                        # Skip comments and certain patterns
                        if '//' in line or '/*' in line:
                            continue
                        if 'import ' in line or '#' in line:
                            continue
                        if '.localized' in line or 'String(localized:' in line:
                            continue
                        if 'LocalizedStringKey' in line:
                            continue

                        # Find string literals
                        matches = string_pattern.findall(line)
                        for match in matches:
                            string_value = match[0] if isinstance(match, tuple) else match
                            # Filter out likely non-localizable strings
                            if self._should_check_string(string_value):
                                results.append((str(swift_file), line_num, string_value))
            except Exception as e:
                print(f"Warning: Error reading {swift_file}: {e}", file=sys.stderr)

        return results

    def _should_check_string(self, s: str) -> bool:
        """Determine if a string should be checked for localization"""
        # Skip empty strings
        if not s.strip():
            return False

        # Skip single characters
        if len(s) <= 1:
            return False

        # Skip common non-localizable patterns
        skip_patterns = [
            r'^https?://',  # URLs
            r'^[A-Z_]+$',   # Constants
            r'^\d+$',       # Numbers
            r'^[@#\$%\^&\*]',  # Special chars
            r'^\.',         # Dot notation
            r'^\\',         # Escape sequences
        ]

        for pattern in skip_patterns:
            if re.match(pattern, s):
                return False

        return True

    def audit_localization(self, path: str) -> Tuple[List[Tuple[str, int, str]], List[str]]:
        """
        Audit localization coverage by finding:
        1. Strings using .localized that don't exist in Localizable.xcstrings
        2. Potential user-facing strings that aren't localized

        Returns: (missing_keys, unlocalized_strings)
        """
        if not self.data:
            return ([], [])

        missing_keys = []
        path_obj = Path(path)

        if not path_obj.exists():
            print(f"Error: Path '{path}' not found", file=sys.stderr)
            return ([], [])

        # Get all existing keys from Localizable.xcstrings
        existing_keys = set(self.data.get('strings', {}).keys())

        # Find all Swift files
        if path_obj.is_file():
            swift_files = [path_obj] if path_obj.suffix == '.swift' else []
        else:
            swift_files = list(path_obj.rglob('*.swift'))

        # Pattern to find .localized calls: "key".localized or "key".asLoclizedKey
        localized_pattern = re.compile(r'"([^"]+)"\.(?:localized|asLoclizedKey)')

        for swift_file in swift_files:
            try:
                with open(swift_file, 'r', encoding='utf-8') as f:
                    for line_num, line in enumerate(f, 1):
                        # Skip comments
                        if '//' in line or '/*' in line:
                            continue

                        # Find .localized calls
                        matches = localized_pattern.findall(line)
                        for key in matches:
                            if key not in existing_keys:
                                missing_keys.append((str(swift_file), line_num, key))
            except Exception as e:
                print(f"Warning: Error reading {swift_file}: {e}", file=sys.stderr)

        return (missing_keys, [])

    def get_all_keys(self) -> List[str]:
        """Get all localization keys"""
        if not self.data:
            return []
        return sorted(self.data.get('strings', {}).keys())

    def normalize_keys(self) -> List[Tuple[str, str, str]]:
        """
        Find keys that don't follow the standard dot-notation format.

        Returns: List of (key, en_value, suggested_key) tuples
        """
        if not self.data:
            return []

        non_standard_keys = []
        strings = self.data.get('strings', {})

        # Pattern for valid dot-notation keys: category.subcategory.item
        # Must start with lowercase letter, contain at least one dot, only lowercase/numbers/dots/underscores
        valid_pattern = re.compile(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$')

        for key in sorted(strings.keys()):
            # Check if key follows the dot-notation pattern
            if not valid_pattern.match(key):
                # Get English value
                localizations = strings[key].get('localizations', {})
                en_value = localizations.get('en', {}).get('stringUnit', {}).get('value', '')

                # Suggest a proper key format
                suggested_key = self._suggest_proper_key(key, en_value)
                non_standard_keys.append((key, en_value, suggested_key))

        return non_standard_keys

    def _suggest_proper_key(self, current_key: str, en_value: str) -> str:
        """Suggest a proper dot-notation key based on the current key or English value"""
        # If current key uses underscores, convert to dots
        if '_' in current_key and '.' not in current_key:
            return current_key.replace('_', '.')

        # If key is English text, suggest based on common patterns
        suggestions_map = {
            'Try Again': 'common.try_again',
            'OK': 'common.ok',
            'Unable to preview document': 'preview.error.unable_to_preview',
            'Error': 'common.error',
            'AI CV Generation': 'ai.generation.title',
            'AI-Powered CV Generation': 'ai.generation.powered_title',
            'Generate CV with AI': 'ai.generation.generate_button',
            'Example': 'common.example',
            'Your Professional Background': 'ai.generation.background_title',
            'Maya Chen': 'preview.sample_name',
            'Aa': 'preview.text_size_indicator',
            'Describe your background and let AI create your CV': 'ai.generation.description',
            'Describe your professional background in detail. Include: name, email, phone, location, job titles, companies, years of experience, education, skills, and languages.': 'ai.generation.prompt_placeholder',
            'Include: name, email, phone, location, job titles, companies, years of experience, education, skills, and languages.': 'ai.generation.prompt_hint',
            '%@. %@': 'common.format.sentence_join',
        }

        if current_key in suggestions_map:
            return suggestions_map[current_key]

        # Generic suggestion: convert to snake_case and add common. prefix
        normalized = en_value.lower()
        normalized = re.sub(r'[^\w\s]', '', normalized)
        normalized = re.sub(r'\s+', '_', normalized)
        normalized = normalized[:50]  # Limit length

        return f'common.{normalized}'

    def fix_key(self, old_key: str, new_key: str, update_code_path: Optional[str] = None) -> bool:
        """
        Migrate an improperly formatted key to a new properly formatted key.

        1. Get all translations from old key
        2. Add new key with all translations
        3. Optionally update code references from old_key to new_key
        4. Keep old key (manual removal later)

        Returns: True if successful
        """
        if not self.data:
            return False

        # Get translations from old key
        translations = self.get_key(old_key)
        if not translations:
            print(f"Error: Cannot migrate - old key '{old_key}' not found", file=sys.stderr)
            return False

        # Check if new key already exists
        if new_key in self.data.get('strings', {}):
            print(f"✅ New key '{new_key}' already exists - skipping add")
        else:
            # Add new key with all translations
            if not self.add_key(new_key, translations):
                return False

        print(f"   Migrated: '{old_key}' → '{new_key}'")

        # Update code references if path provided
        if update_code_path:
            updated_files = self._update_code_references(old_key, new_key, update_code_path)
            if updated_files:
                print(f"   Updated {len(updated_files)} file(s):")
                for file_path in updated_files:
                    print(f"     - {file_path}")

        return True

    def _update_code_references(self, old_key: str, new_key: str, path: str) -> List[str]:
        """Update code references from old_key to new_key in Swift files"""
        updated_files = []
        path_obj = Path(path)

        if not path_obj.exists():
            print(f"Warning: Path '{path}' not found", file=sys.stderr)
            return updated_files

        # Find all Swift files
        if path_obj.is_file():
            swift_files = [path_obj] if path_obj.suffix == '.swift' else []
        else:
            swift_files = list(path_obj.rglob('*.swift'))

        for swift_file in swift_files:
            try:
                with open(swift_file, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Check if old key is referenced
                if f'"{old_key}"' not in content:
                    continue

                # Replace references
                # Pattern: "old_key".localized or "old_key".asLoclizedKey or String(localized: "old_key")
                updated_content = content
                updated_content = updated_content.replace(f'"{old_key}".localized', f'"{new_key}".localized')
                updated_content = updated_content.replace(f'"{old_key}".asLoclizedKey', f'"{new_key}".asLoclizedKey')
                updated_content = updated_content.replace(f'String(localized: "{old_key}")', f'String(localized: "{new_key}")')

                # Save if changed
                if updated_content != content:
                    with open(swift_file, 'w', encoding='utf-8') as f:
                        f.write(updated_content)
                    updated_files.append(str(swift_file))

            except Exception as e:
                print(f"Warning: Error updating {swift_file}: {e}", file=sys.stderr)

        return updated_files

    def fix_all_nonstandard_keys(self, update_code_path: Optional[str] = None) -> Tuple[int, int]:
        """
        Fix all non-standard keys by migrating them to properly formatted keys.

        Returns: (successful_count, failed_count)
        """
        non_standard = self.normalize_keys()
        if not non_standard:
            print("✅ All keys already follow standard format")
            return (0, 0)

        successful = 0
        failed = 0

        print(f"\n🔧 Migrating {len(non_standard)} non-standard key(s)...\n")

        for old_key, en_value, suggested_key in non_standard:
            preview = en_value[:40] + '...' if len(en_value) > 40 else en_value
            print(f"Migrating: \"{old_key}\" ({preview})")

            if self.fix_key(old_key, suggested_key, update_code_path):
                successful += 1
            else:
                failed += 1
            print()

        return (successful, failed)

    def check_translation_coverage(self) -> Dict[str, List[str]]:
        """
        Check translation coverage for all keys.

        Returns: Dictionary mapping keys to list of missing languages
        """
        if not self.data:
            return {}

        incomplete_keys = {}
        strings = self.data.get('strings', {})

        for key in sorted(strings.keys()):
            entry = strings[key]
            localizations = entry.get('localizations', {})

            # Skip empty entries
            if not localizations:
                continue

            missing_langs = []
            for lang in SUPPORTED_LANGUAGES:
                if lang not in localizations:
                    missing_langs.append(lang)
                else:
                    # Check if translation value is empty
                    value = localizations[lang].get('stringUnit', {}).get('value', '')
                    if not value or not value.strip():
                        missing_langs.append(lang)

            if missing_langs:
                incomplete_keys[key] = missing_langs

        return incomplete_keys

    def clean_empty_keys(self) -> List[str]:
        """
        Remove keys with no translations (empty {} entries).

        Returns: List of removed keys
        """
        if not self.data:
            return []

        strings = self.data.get('strings', {})
        empty_keys = []

        # Find empty entries
        for key in list(strings.keys()):
            entry = strings[key]
            localizations = entry.get('localizations', {})

            if not localizations:
                empty_keys.append(key)
                del strings[key]

        return empty_keys


def main():
    parser = argparse.ArgumentParser(
        description='Manage Localizable.xcstrings localization file'
    )
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # Add command
    add_parser = subparsers.add_parser('add', help='Add a new localization key')
    add_parser.add_argument('--key', required=True, help='Localization key')
    add_parser.add_argument('--en', required=True, help='English translation')
    add_parser.add_argument('--es', required=True, help='Spanish translation')
    add_parser.add_argument('--fr', required=True, help='French translation')
    add_parser.add_argument('--de', required=True, help='German translation')
    add_parser.add_argument('--it', required=True, help='Italian translation')
    add_parser.add_argument('--pt', required=True, help='Portuguese translation')

    # Get command
    get_parser = subparsers.add_parser('get', help='Get translations for a key')
    get_parser.add_argument('--key', required=True, help='Localization key')

    # List command
    list_parser = subparsers.add_parser('list', help='List all keys')
    list_parser.add_argument('--filter', help='Filter keys by pattern')

    # Update command
    update_parser = subparsers.add_parser('update', help='Update a translation')
    update_parser.add_argument('--key', required=True, help='Localization key')
    update_parser.add_argument('--lang', required=True, choices=SUPPORTED_LANGUAGES, help='Language code')
    update_parser.add_argument('--value', required=True, help='New translation value')

    # Check command
    check_parser = subparsers.add_parser('check', help='Find hardcoded strings')
    check_parser.add_argument('--path', required=True, help='Path to check (file or directory)')

    # Audit command
    audit_parser = subparsers.add_parser('audit', help='Audit localization coverage (find missing keys)')
    audit_parser.add_argument('--path', required=True, help='Path to audit (file or directory)')

    # Normalize command
    normalize_parser = subparsers.add_parser('normalize', help='Find keys with non-standard format')

    # Fix command
    fix_parser = subparsers.add_parser('fix', help='Migrate all non-standard keys to proper dot-notation format')
    fix_parser.add_argument('--path', help='Path to update code references (optional)')

    # Coverage command
    coverage_parser = subparsers.add_parser('coverage', help='Check translation coverage across all languages')
    coverage_parser.add_argument('--verbose', '-v', action='store_true', help='Show all missing translations')

    # Clean command
    clean_parser = subparsers.add_parser('clean', help='Remove empty localization entries (keys with no translations)')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    manager = L10nManager()

    # Commands that need to load the file
    if args.command in ['add', 'get', 'list', 'update', 'audit', 'normalize', 'fix', 'coverage', 'clean']:
        if not manager.load():
            return 1

    # Execute command
    if args.command == 'add':
        translations = {
            'en': args.en,
            'es': args.es,
            'fr': args.fr,
            'de': args.de,
            'it': args.it,
            'pt': args.pt
        }
        if manager.add_key(args.key, translations):
            if manager.save():
                return 0
        return 1

    elif args.command == 'get':
        translations = manager.get_key(args.key)
        if translations:
            print(f"\nTranslations for '{args.key}':")
            for lang in SUPPORTED_LANGUAGES:
                print(f"  {lang}: {translations.get(lang, '')}")
            return 0
        return 1

    elif args.command == 'list':
        keys = manager.list_keys(args.filter)
        if keys:
            print(f"\nFound {len(keys)} key(s):")
            for key, en_value in keys:
                preview = en_value[:50] + '...' if len(en_value) > 50 else en_value
                print(f"  {key}: {preview}")
        else:
            print("No keys found")
        return 0

    elif args.command == 'update':
        if manager.update_key(args.key, args.lang, args.value):
            if manager.save():
                return 0
        return 1

    elif args.command == 'check':
        results = manager.check_hardcoded_strings(args.path)
        if results:
            print(f"\nFound {len(results)} potential hardcoded string(s):\n")
            for file_path, line_num, string_value in results:
                print(f"  {file_path}:{line_num}")
                print(f"    \"{string_value}\"")
                print()
        else:
            print("✅ No hardcoded strings found")
        return 0

    elif args.command == 'audit':
        missing_keys, _ = manager.audit_localization(args.path)
        if missing_keys:
            print(f"\n❌ Found {len(missing_keys)} missing localization key(s):\n")
            for file_path, line_num, key in missing_keys:
                print(f"  {file_path}:{line_num}")
                print(f"    Key: \"{key}\"")
                print(f"    ⚠️  This key is used in code but NOT found in Localizable.xcstrings")
                print()
            print(f"\n💡 Tip: Add missing keys using:")
            print(f"   python3 l10n_manager.py add --key \"<key>\" --en \"<value>\" ...")
            return 1
        else:
            print("✅ All localization keys are present in Localizable.xcstrings")
            return 0

    elif args.command == 'normalize':
        non_standard_keys = manager.normalize_keys()
        if non_standard_keys:
            print(f"\n🔍 Found {len(non_standard_keys)} key(s) with non-standard format:\n")
            print("Improperly formatted keys:")
            for i, (key, en_value, suggested_key) in enumerate(non_standard_keys, 1):
                preview = en_value[:40] + '...' if len(en_value) > 40 else en_value
                print(f"  {i}. \"{key}\" ({preview})")
                print(f"     → Suggested: \"{suggested_key}\"")
                print()
            print("\n💡 Steps to fix:")
            print("  1. Add new keys with proper format using /l10n add")
            print("  2. Update code references to use new keys")
            print("  3. Remove old improperly formatted keys")
            return 1
        else:
            print("✅ All localization keys follow the standard dot-notation format")
            return 0

    elif args.command == 'fix':
        update_path = args.path if hasattr(args, 'path') else None
        successful, failed = manager.fix_all_nonstandard_keys(update_path)

        if successful > 0 or failed > 0:
            if manager.save():
                print(f"\n✅ Migration complete!")
                print(f"   Successful: {successful}")
                if failed > 0:
                    print(f"   Failed: {failed}")
                print(f"\n💡 Next steps:")
                print(f"  1. Review the changes in Localizable.xcstrings")
                print(f"  2. Run /l10n audit to verify no broken references")
                print(f"  3. Manually remove old keys if everything works")
                return 0 if failed == 0 else 1
            else:
                print(f"Error: Failed to save changes", file=sys.stderr)
                return 1
        return 0

    elif args.command == 'coverage':
        incomplete_keys = manager.check_translation_coverage()

        if incomplete_keys:
            total_keys = len(manager.get_all_keys())
            complete_keys = total_keys - len(incomplete_keys)
            coverage_percent = (complete_keys / total_keys * 100) if total_keys > 0 else 0

            print(f"\n📊 Translation Coverage Report")
            print(f"   Total keys: {total_keys}")
            print(f"   Complete: {complete_keys} ({coverage_percent:.1f}%)")
            print(f"   Incomplete: {len(incomplete_keys)}")
            print(f"\n❌ Keys with incomplete translations:\n")

            # Group by missing language count
            by_missing_count = {}
            for key, missing_langs in incomplete_keys.items():
                count = len(missing_langs)
                if count not in by_missing_count:
                    by_missing_count[count] = []
                by_missing_count[count].append((key, missing_langs))

            # Show grouped results
            for missing_count in sorted(by_missing_count.keys(), reverse=True):
                keys_with_count = by_missing_count[missing_count]
                print(f"Missing {missing_count}/{len(SUPPORTED_LANGUAGES)} language(s): {len(keys_with_count)} key(s)")

                if args.verbose:
                    for key, missing_langs in sorted(keys_with_count):
                        langs_str = ', '.join(missing_langs)
                        print(f"  • {key}")
                        print(f"    Missing: {langs_str}")
                    print()
                else:
                    # Show first 5 examples
                    for key, missing_langs in sorted(keys_with_count)[:5]:
                        langs_str = ', '.join(missing_langs)
                        print(f"  • {key} (missing: {langs_str})")
                    if len(keys_with_count) > 5:
                        print(f"  ... and {len(keys_with_count) - 5} more")
                    print()

            print(f"💡 Tip: Use --verbose flag to see all incomplete keys")
            print(f"💡 Add missing translations using:")
            print(f"   python3 l10n_manager.py update --key \"<key>\" --lang <lang> --value \"<translation>\"")
            return 1
        else:
            print("✅ All localization keys have complete translations across all 6 languages!")
            return 0

    elif args.command == 'clean':
        empty_keys = manager.clean_empty_keys()

        if empty_keys:
            print(f"\n🧹 Found {len(empty_keys)} empty key(s):\n")
            for key in sorted(empty_keys):
                print(f"  • {key}")

            if manager.save():
                print(f"\n✅ Removed {len(empty_keys)} empty key(s) from Localizable.xcstrings")
                return 0
            else:
                print(f"Error: Failed to save changes", file=sys.stderr)
                return 1
        else:
            print("✅ No empty keys found in Localizable.xcstrings")
            return 0

    return 1


if __name__ == '__main__':
    sys.exit(main())

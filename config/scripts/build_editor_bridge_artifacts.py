#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import plistlib
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = REPO_ROOT / "Sources" / "EditorBridgeApp" / "Resources" / "default-config.plist"
DEFAULT_MANIFEST = REPO_ROOT / "Sources" / "EditorBridgeApp" / "Resources" / "default-programmable-files.json"
CUSTOM_UTI = "dev.editorbridge.programmable.custom"
STATIC_BASE_UTIS = [
    "public.source-code",
    "public.script",
    "public.shell-script",
    "public.json",
    "public.xml",
    "com.netscape.javascript-source",
    "net.daringfireball.markdown",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--fragment", type=Path, required=True)
    parser.add_argument("--uti-list", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--ensure-config", action="store_true")
    return parser.parse_args()


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def ensure_config(path: Path) -> None:
    if path.exists():
        return
    ensure_parent(path)
    path.write_bytes(DEFAULT_CONFIG.read_bytes())


def load_plist(path: Path) -> dict:
    with path.open("rb") as handle:
        return plistlib.load(handle)


def load_manifest(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def normalize_extension(value: str) -> str:
    stripped = value.strip().lower()
    return stripped[1:] if stripped.startswith(".") else stripped


def normalize_filename(value: str) -> str:
    return value.strip()


def string_list(values: object) -> list[str]:
    if not isinstance(values, list):
        return []
    return [str(item) for item in values if str(item).strip()]


def compute_types(config: dict, manifest: dict) -> tuple[list[str], list[str], list[str]]:
    associations = config.get("associations", {})
    extensions: set[str] = set()
    filenames: set[str] = set()

    if associations.get("includeProgrammingPreset", True):
        extensions.update(normalize_extension(item) for item in manifest.get("extensions", []))
        filenames.update(normalize_filename(item) for item in manifest.get("filenames", []))

    extensions.update(normalize_extension(item) for item in string_list(associations.get("customExtensions", [])))
    filenames.update(normalize_filename(item) for item in string_list(associations.get("customFilenames", [])))

    extensions.difference_update(
        normalize_extension(item) for item in string_list(associations.get("excludedExtensions", []))
    )
    filenames.difference_update(
        normalize_filename(item) for item in string_list(associations.get("excludedFilenames", []))
    )

    utis: list[str] = []
    if associations.get("includeStaticBaseTypes", True):
        utis.extend(STATIC_BASE_UTIS)
    if associations.get("includePlainText", False):
        utis.append("public.plain-text")
    if associations.get("includePublicData", False):
        utis.append("public.data")
    utis.extend(string_list(associations.get("extraContentTypes", [])))

    if extensions or filenames:
        utis.append(CUSTOM_UTI)

    normalized_utis = sorted({item for item in utis if item})
    return sorted(extensions), sorted(filenames), normalized_utis


def build_fragment(extensions: list[str], filenames: list[str], utis: list[str]) -> dict:
    fragment: dict[str, object] = {}

    if extensions or filenames:
        tag_spec: dict[str, list[str]] = {}
        if extensions:
            tag_spec["public.filename-extension"] = extensions
        if filenames:
            tag_spec["public.filename"] = filenames
        fragment["UTExportedTypeDeclarations"] = [
            {
                "UTTypeIdentifier": CUSTOM_UTI,
                "UTTypeDescription": "Editor Bridge Custom Programmable Files",
                "UTTypeConformsTo": ["public.plain-text"],
                "UTTypeTagSpecification": tag_spec,
            }
        ]

    if utis:
        bundle_types = [
            {
                "CFBundleTypeName": "Editor Bridge Files",
                "CFBundleTypeRole": "Viewer",
                "LSHandlerRank": "Owner",
                "LSItemContentTypes": utis,
            }
        ]
        fragment["CFBundleDocumentTypes"] = bundle_types

    return fragment


def main() -> int:
    args = parse_args()
    if args.ensure_config:
        ensure_config(args.config)

    config = load_plist(args.config)
    manifest = load_manifest(args.manifest)

    extensions, filenames, utis = compute_types(config, manifest)
    fragment = build_fragment(extensions, filenames, utis)

    ensure_parent(args.fragment)
    with args.fragment.open("wb") as handle:
        plistlib.dump(fragment, handle, sort_keys=False)

    ensure_parent(args.uti_list)
    args.uti_list.write_text("\n".join(utis) + ("\n" if utis else ""), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Generate a self-contained, pannable/zoomable HTML view of a Nix dependency
graph. Reads `nix-store -q --graph <paths>` DOT output on stdin, renders it
with a force-directed layout that runs live in the browser (d3-force +
canvas), and writes a single HTML file with the graph data inlined --
no server, no external files, works straight from `file://`. Clicking a
node pops up real metadata for it (NAR/closure size, deriver, registration
date, which of the given roots it belongs to, its description) pulled in
bulk from `nix path-info` / `nix-store -q --requisites` / a description
scan at generation time.

Usage:
  nix-store -q --graph <paths...> \
    | nix-graph-viewer.py <output.html> <flake-dir> <list-attr1>[,<list-attr2>...] \
      <Label1>=<path1> [<Label2>=<path2> ...]

Each <list-attrN> is a flake attribute holding a LIST of packages (e.g.
"nixosConfigurations.laptop.config.environment.systemPackages",
"homeConfigurations.roey.config.home.packages") -- descriptions are only
fetched for these explicitly-installed packages, not the full nixpkgs
tree (scanning all ~100k nixpkgs attributes for meta.description was
tried and took 10+ minutes without finishing; the packages a user
actually installed is a far smaller, far more relevant set and finishes
in well under a minute). Still cached to disk (keyed by flake.lock's
hash) so repeat runs skip even that cost.

The <Label>=<path> arguments must be the same roots passed to
`nix-store -q --graph`, used to classify each node by which root(s)'
closure it belongs to (e.g. "NixOS", "Home Manager", or both).
"""
import sys
import os
import re
import json
import hashlib
import subprocess
from pathlib import Path

EDGE_RE = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*->\s*"((?:[^"\\]|\\.)*)"')
HASH_PREFIX_RE = re.compile(r'^[a-z0-9]{32}-')
STORE = "/nix/store/"


def parse_dot(lines) -> tuple[list[str], list[tuple[int, int]]]:
    """Returns (store_path_names, edges). store_path_names[i] is the full
    "<hash>-<name>" store basename (no /nix/store/ prefix) for node i."""
    node_ids: dict[str, int] = {}
    edges: list[tuple[int, int]] = []
    for line in lines:
        m = EDGE_RE.match(line.strip())
        if not m:
            continue
        src, dst = m.group(1), m.group(2)
        node_ids.setdefault(src, len(node_ids))
        node_ids.setdefault(dst, len(node_ids))
        edges.append((node_ids[src], node_ids[dst]))
    names: list[str] = [""] * len(node_ids)
    for name, idx in node_ids.items():
        names[idx] = name
    return names, edges


def fetch_path_info(store_names: list[str]) -> dict[str, dict]:
    """Batch-query `nix path-info` for every node in one process. Returns a
    dict keyed by full store path. Never raises -- on failure, returns {}
    and the popup just shows less detail."""
    full_paths = [STORE + n for n in store_names]
    try:
        result = subprocess.run(
            ["nix", "path-info", "--json", "--closure-size", *full_paths],
            capture_output=True, text=True, check=True, timeout=60,
        )
        entries = json.loads(result.stdout)
        # nix path-info --json returns either a list (older) or an object
        # keyed by path (newer); normalize to a dict keyed by path.
        if isinstance(entries, list):
            return {e["path"]: e for e in entries if "path" in e}
        return entries
    except Exception as e:
        print(f"warning: nix path-info failed, popups will show less detail: {e}", file=sys.stderr)
        return {}


def fetch_roots(roots: list[tuple[str, str]]) -> list[tuple[str, set[str]]]:
    """For each (label, path) root, query its full closure (--requisites).
    Used to classify every node by which root(s) it belongs to."""
    membership = []
    for label, path in roots:
        try:
            result = subprocess.run(
                ["nix-store", "-q", "--requisites", path],
                capture_output=True, text=True, check=True, timeout=30,
            )
            membership.append((label, set(result.stdout.split())))
        except Exception as e:
            print(f"warning: --requisites failed for {label} ({path}): {e}", file=sys.stderr)
            membership.append((label, set()))
    return membership


# Applied to a LIST of packages (e.g. environment.systemPackages), not an
# attrset -- scanning meta.description across all ~100k nixpkgs attributes
# was tried and took 10+ minutes without finishing; the packages a user
# actually installed is a far smaller, far more relevant set.
LIST_DESCRIPTION_SCAN = '''
pkgs: map (v: let
  r = builtins.tryEval (let d = { desc = v.meta.description or null; path = v.outPath or null; }; in builtins.deepSeq d d);
in if r.success then r.value else null) pkgs
'''


def fetch_descriptions(flake_dir: str, list_attrs: list[str]) -> dict[str, str]:
    """Store path -> meta.description, for packages in the given flake
    list-attributes (each must evaluate to a list of derivations, e.g.
    environment.systemPackages). Cached to disk keyed by flake.lock's hash
    so repeat runs against the same flake.lock skip the nix eval entirely."""
    lock_file = Path(flake_dir) / "flake.lock"
    try:
        key = hashlib.sha256(lock_file.read_bytes() + ":".join(list_attrs).encode()).hexdigest()[:16]
    except OSError:
        key = "nolock"
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "nix-graph-viewer"
    cache_file = cache_dir / f"descriptions-{key}.json"

    if cache_file.exists():
        try:
            return json.loads(cache_file.read_text())
        except (OSError, json.JSONDecodeError):
            pass  # fall through and rebuild

    by_path: dict[str, str] = {}
    for attr in list_attrs:
        print(f"fetching descriptions for {attr}...", file=sys.stderr)
        try:
            result = subprocess.run(
                ["nix", "eval", "--json", f"{flake_dir}#{attr}", "--apply", LIST_DESCRIPTION_SCAN],
                capture_output=True, text=True, check=True, timeout=120,
            )
            entries = json.loads(result.stdout)
            for entry in entries:
                if entry and entry.get("path") and entry.get("desc"):
                    by_path[entry["path"]] = entry["desc"]
        except Exception as e:
            print(f"warning: description scan of {attr} failed, skipping: {e}", file=sys.stderr)

    try:
        cache_dir.mkdir(parents=True, exist_ok=True)
        cache_file.write_text(json.dumps(by_path))
    except OSError as e:
        print(f"warning: couldn't write description cache: {e}", file=sys.stderr)
    return by_path


def executables_for(full_path: str) -> list[str]:
    """Executable file names in <path>/bin, if any -- what this package
    actually puts on your PATH."""
    bin_dir = Path(full_path) / "bin"
    try:
        if not bin_dir.is_dir():
            return []
        return sorted(
            entry.name for entry in bin_dir.iterdir()
            if entry.is_file() and os.access(entry, os.X_OK)
        )
    except OSError:
        return []


def build_meta(
    store_names: list[str],
    info: dict[str, dict],
    membership: list[tuple[str, set[str]]],
    descriptions: dict[str, str],
) -> list[dict]:
    meta = []
    for name in store_names:
        full = STORE + name
        entry = info.get(full)
        deriver = None
        if entry:
            deriver = entry.get("deriver")
            if deriver and deriver != "unknown-deriver":
                deriver = HASH_PREFIX_RE.sub('', Path(deriver).name)
            else:
                deriver = None
        meta.append({
            "narSize": entry.get("narSize") if entry else None,
            "closureSize": entry.get("closureSize") if entry else None,
            "deriver": deriver,
            "registrationTime": entry.get("registrationTime") if entry else None,
            "source": [label for label, paths in membership if full in paths],
            "executables": executables_for(full),
            "description": descriptions.get(full),
        })
    return meta


def main():
    if len(sys.argv) < 5:
        sys.exit(
            f"usage: {sys.argv[0]} <output.html> <flake-dir> <list-attr1>[,<list-attr2>...] "
            f"<Label1>=<path1> [<Label2>=<path2> ...]"
        )
    out_path = Path(sys.argv[1])
    flake_dir = sys.argv[2]
    list_attrs = [a for a in sys.argv[3].split(",") if a]
    roots = []
    for arg in sys.argv[4:]:
        if "=" not in arg:
            sys.exit(f"expected <Label>=<path>, got: {arg!r}")
        label, path = arg.split("=", 1)
        roots.append((label, path))

    store_names, edges = parse_dot(sys.stdin)
    if not store_names:
        sys.exit("no edges found on stdin -- expected `nix-store -q --graph` DOT output")

    labels = [HASH_PREFIX_RE.sub('', n) for n in store_names]

    info = fetch_path_info(store_names)
    membership = fetch_roots(roots)
    descriptions = fetch_descriptions(flake_dir, list_attrs)
    meta = build_meta(store_names, info, membership, descriptions)

    template = (Path(__file__).parent / "nix-graph-viewer.template.html").read_text()
    data_json = json.dumps({
        "nodes": labels,
        "paths": [STORE + n for n in store_names],
        "edges": edges,
        "meta": meta,
    })
    html = template.replace("/*__GRAPH_DATA_JSON__*/", data_json)
    out_path.write_text(html)

    print(f"{len(labels)} nodes, {len(edges)} edges -> {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()

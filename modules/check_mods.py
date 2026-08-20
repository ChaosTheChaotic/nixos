# flake8: noqa: E501
import json
import os
import re
import sys
from functools import total_ordering
from typing import Any


@total_ordering
class SmodsVersion:
    def __init__(self, v_str: Any = "0.0.0"):
        v_str = str(v_str) if v_str else "0.0.0"
        m = re.match(r"^(\d+)(\.?([\d\*]*))(\.?([\d\*]*))(.*)$", v_str)
        if not m:
            self.major, self.minor, self.patch, self.rev, self.beta = (
                -1,
                0,
                0,
                "",
                0,
            )
            return

        major, minor_full, minor, patch_full, patch, rev = m.groups()

        # Handle trailing dots
        if (minor_full and not minor) or (patch_full and not patch):
            self.major, self.minor, self.patch, self.rev, self.beta = (
                -1,
                0,
                0,
                "",
                0,
            )
            return

        self.major = int(major) if major else 0
        self.minor = -2 if "*" in minor else (int(minor) if minor else 0)
        self.patch = -2 if "*" in patch else (int(patch) if patch else 0)
        self.rev = rev or ""
        self.beta = -1 if (self.rev and self.rev.startswith("~")) else 0

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, SmodsVersion):
            if isinstance(other, (str, int)):
                other = SmodsVersion(str(other))
            else:
                return False

        minor_wildcard = self.minor == -2 or other.minor == -2
        patch_wildcard = self.patch == -2 or other.patch == -2
        beta_wildcard = self.rev == "~" or other.rev == "~"

        return (
            self.major == other.major
            and (self.minor == other.minor or minor_wildcard)
            and (self.patch == other.patch or minor_wildcard or patch_wildcard)
            and (
                self.rev == other.rev
                or minor_wildcard
                or patch_wildcard
                or beta_wildcard
            )
            and (beta_wildcard or self.beta == other.beta)
        )

    def _normalize(self) -> tuple[int, int, int, int, str]:
        maj = self.major + (1 if self.minor == -2 else 0)
        min_ = 0 if self.minor == -2 else (self.minor + (1 if self.patch == -2 else 0))
        pat = 0 if self.patch == -2 else self.patch
        return maj, min_, pat, self.beta, self.rev

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, SmodsVersion):
            if isinstance(other, (str, int)):
                other = SmodsVersion(str(other))
            else:
                return NotImplemented

        # maj -> min_ -> pat -> beta -> rev
        return self._normalize() < other._normalize()


def check_constraint(installed_v_str: str, op: str | None, req_v_str: str) -> bool:
    installed_v = SmodsVersion(installed_v_str)
    req_v = SmodsVersion(req_v_str)
    op = op or ">="

    if op == "==":
        return installed_v == req_v
    if op in (">", ">>"):
        return installed_v > req_v
    if op in ("<", "<<"):
        return installed_v < req_v
    if op == ">=":
        return installed_v >= req_v
    if op == "<=":
        return installed_v <= req_v
    return installed_v >= req_v


def parse_deps(dep_str: str) -> list[dict[str, Any]]:
    # Handle alt deps
    options = []
    for opt in dep_str.split("|"):
        opt = opt.strip()

        # Handle thunderstore fmt
        ts_m = re.match(r"^([a-zA-Z0-9_]+)-(.+)-(\d+\.\d+\.\d+[a-zA-Z0-9_.~-]*)$", opt)
        if ts_m:
            mod_id = ts_m.group(2)
            req_ver = ts_m.group(3)

            # Normalize core mod names explicitly
            if mod_id.lower() == "lovely":
                mod_id = "Lovely"
            elif mod_id.lower() == "steamodded":
                mod_id = "Steamodded"

            options.append({"id": mod_id, "constraints": [(">=", req_ver)]})
            continue

        # Handle steamodded formats
        m = re.match(r"^([a-zA-Z0-9_\-]+)", opt)
        if not m:
            continue
        mod_id = m.group(1)

        # Normalize core mod names explicitly
        if mod_id.lower() == "lovely":
            mod_id = "Lovely"
        elif mod_id.lower() == "steamodded":
            mod_id = "Steamodded"

        rest = opt[len(mod_id) :].strip()
        constraints = []

        if "(" in rest:
            # New fmt
            for b in re.findall(r"\(([^)]+)\)", rest):
                op_m = re.match(r"^(>=|<=|==|>>|<<|>|<)?\s*(.*)$", b.strip())
                if op_m:
                    constraints.append((op_m.group(1), op_m.group(2)))
        else:
            # Old fmt
            constraints.extend(
                re.findall(r"(>=|<=|==|>>|<<|>|<)\s*([0-9a-zA-Z.*~-]+)", rest)
            )

        options.append({"id": mod_id, "constraints": constraints})
    return options


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: check_mods.py <mod_dir>")
        sys.exit(1)

    mod_dir = sys.argv[1]
    mods: dict[str, dict[str, Any]] = {}

    # Get mod meta
    for f in os.listdir(mod_dir):
        path = os.path.join(mod_dir, f)
        if not os.path.isdir(path):
            continue

        mod_id, version = f, "0.0.0"
        deps, confs, provides = [], [], []

        json_f = [x for x in os.listdir(path) if x.endswith(".json")]
        lua_f = [x for x in os.listdir(path) if x.endswith(".lua")]

        parsed_manifest = False

        # Find the relevant data
        if json_f:
            for jf in json_f:
                try:
                    with open(os.path.join(path, jf)) as fp:
                        raw_data = fp.read()
                        clean_data = re.sub(r",\s*([\]}])", r"\1", raw_data)
                        data = json.loads(clean_data)

                        # Check for 'id' to be more sure that it is a steamodded file
                        if "id" in data:
                            mod_id = data["id"]
                            version = data.get("version", version)
                            deps = data.get("dependencies", [])
                            confs = data.get("conflicts", [])
                            provides = data.get("provides", [])
                            parsed_manifest = True
                            break
                except Exception:
                    pass

        if not parsed_manifest and lua_f:
            for lf in lua_f:
                try:
                    with open(os.path.join(path, lf)) as fp:
                        lines = [line.strip() for line in fp.readlines()][:30]
                        if lines and lines[0] == "--- STEAMODDED HEADER":
                            for line in lines:
                                if line.startswith("--- MOD_ID:"):
                                    mod_id = line.split(":", 1)[1].strip()
                                if line.startswith("--- VERSION:"):
                                    version = line.split(":", 1)[1].strip()
                                if line.startswith("--- DEPENDENCIES:"):
                                    deps = [
                                        d.strip()
                                        for d in line.split(":", 1)[1]
                                        .strip()
                                        .strip("[]")
                                        .split(",")
                                        if d.strip()
                                    ]
                                if line.startswith("--- CONFLICTS:"):
                                    confs = [
                                        c.strip()
                                        for c in line.split(":", 1)[1]
                                        .strip()
                                        .strip("[]")
                                        .split(",")
                                        if c.strip()
                                    ]
                            parsed_manifest = True
                            break
                except Exception:
                    pass

        mods[mod_id] = {"version": version, "deps": deps, "confs": confs}
        for p in provides:
            p_id = re.split(r"\s|\(", p)[0]
            m = re.search(r"\(([^)]+)\)", p)
            mods[p_id] = {
                "version": m.group(1) if m else version,
                "deps": [],
                "confs": [],
            }

    # Verify validity of collected data
    errors = []
    core_deps = {"Steamodded", "Lovely", "Balatro"}

    for mid, data in mods.items():
        for dep in data["deps"]:
            resolved = False
            for opt in parse_deps(dep):
                if opt["id"] in core_deps:
                    resolved = True
                    break

                if opt["id"] in mods:
                    target_ver = mods[opt["id"]]["version"]
                    if all(
                        check_constraint(target_ver, op, req)
                        for op, req in opt["constraints"]
                    ):
                        resolved = True
                        break
            if not resolved:
                errors.append(
                    f"Mod '{mid}' missing dependency or invalid version for: {dep}"
                )

        for conf in data["confs"]:
            for opt in parse_deps(conf):
                if opt["id"] in mods:
                    if not opt["constraints"] or all(
                        check_constraint(mods[opt["id"]]["version"], op, req)
                        for op, req in opt["constraints"]
                    ):
                        errors.append(
                            f"Mod '{mid}' conflicts with installed mod version: {conf}"
                        )

    if errors:
        print("\nMod Verification Failed:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

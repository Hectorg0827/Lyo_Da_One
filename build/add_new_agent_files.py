#!/usr/bin/env python3
"""Add the 7 new agentic pipeline files to project.pbxproj."""
import hashlib
import sys
import os

PBXPROJ = os.path.join(os.path.dirname(__file__), "..", "Lyo.xcodeproj", "project.pbxproj")

NEW_FILES = [
    ("AgentBlock.swift", "Sources/Models"),
    ("GeneratedContentStore.swift", "Sources/Services"),
    ("A2UIContentSynthesizer.swift", "Sources/Core/A2UI"),
    ("MessageIntentClassifier.swift", "Sources/Services"),
    ("ChatRouter.swift", "Sources/Services"),
    ("AgenticClassroomViewModel.swift", "Sources/ViewModels"),
    ("AgenticClassroomView.swift", "Sources/Views/Classroom"),
]


def make_id(seed):
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


def main():
    with open(PBXPROJ, "r") as f:
        content = f.read()

    # Filter out files already present
    missing = [(fn, p) for fn, p in NEW_FILES if fn not in content]
    if not missing:
        print("All 7 files already in project.pbxproj!")
        return

    print(f"Files to add: {[m[0] for m in missing]}")

    # Generate IDs
    entries = []
    for fn, path in missing:
        fref = make_id(f"{fn}_fref_agentic")
        bref = make_id(f"{fn}_bref_agentic")
        entries.append((fn, path, fref, bref))

    lines = content.split("\n")
    out = []

    sources_phase_found = False
    in_sources_phase = False

    for i, line in enumerate(lines):
        # --- PBXBuildFile section end ---
        if "/* End PBXBuildFile section */" in line:
            for fn, path, fref, bref in entries:
                out.append(
                    f"\t\t{bref} /* {fn} in Sources */ = "
                    f"{{isa = PBXBuildFile; fileRef = {fref} /* {fn} */; }};"
                )

        # --- PBXFileReference section end ---
        if "/* End PBXFileReference section */" in line:
            for fn, path, fref, bref in entries:
                out.append(
                    f"\t\t{fref} /* {fn} */ = "
                    f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
                    f"path = {fn}; sourceTree = \"<group>\"; }};"
                )

        out.append(line)

        # --- PBXSourcesBuildPhase: insert after "files = (" ---
        if "isa = PBXSourcesBuildPhase" in line:
            in_sources_phase = True
        if in_sources_phase and "files = (" in line and not sources_phase_found:
            sources_phase_found = True
            for fn, path, fref, bref in entries:
                out.append(f"\t\t\t\t{bref} /* {fn} in Sources */,")
            in_sources_phase = False

    content = "\n".join(out)

    # --- Add to PBXGroup children for each parent folder ---
    for fn, path, fref, bref in entries:
        group_name = path.split("/")[-1]
        group_lines = content.split("\n")
        new_lines = []
        inserted = False
        for gi, gline in enumerate(group_lines):
            new_lines.append(gline)
            if inserted:
                continue
            # Match group by path = <name>; within PBXGroup section
            stripped = gline.strip()
            if (f"path = {group_name};" in stripped or f"name = {group_name};" in stripped):
                # Search backwards for "children = ("
                for back in range(gi - 1, max(gi - 8, -1), -1):
                    if "children = (" in group_lines[back]:
                        # Insert right after children = (
                        insert_pos = len(new_lines) - (gi - back)
                        new_lines.insert(insert_pos, f"\t\t\t\t{fref} /* {fn} */,")
                        inserted = True
                        break
        if not inserted:
            print(f"  WARNING: Could not find group '{group_name}' for {fn}")
        content = "\n".join(new_lines)

    with open(PBXPROJ, "w") as f:
        f.write(content)

    print(f"\nSuccessfully added {len(entries)} files to project.pbxproj:")
    for fn, path, fref, bref in entries:
        print(f"  {fn} -> {path} (fref={fref}, bref={bref})")


if __name__ == "__main__":
    main()

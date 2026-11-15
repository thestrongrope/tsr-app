"""Compare two xlsx files (PHP's and the new API's): the sheet names and every cell's kind and text.

Standard library only (zipfile, xml.etree). Usage: uv run python -I tools/export_parity.py <php.xlsx> <new.xlsx>
With --filter COL:PREFIX (and --ignore COLS) only the rows whose cell in that column starts with the prefix are compared, in order, without their row numbers or the ignored columns; it fails when PHP has none.
With --unordered the rows of a sheet are compared as a set (for rows PHP leaves in no defined order, such as two sessions of one class in one week); the sheet names still must match.
Exit 0 when equal; 1 with the first differences printed. Byte-equal files are not the bar: same sheets, same cells.
Styles are not compared (bold and widths are formatting, not figures).
"""
import sys
import zipfile
import xml.etree.ElementTree as ET

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
      "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
      "rel": "http://schemas.openxmlformats.org/package/2006/relationships"}
MAX_PART_BYTES = 50_000_000


def read_part(archive: zipfile.ZipFile, name: str) -> ET.Element:
    info = archive.getinfo(name)
    if info.file_size > MAX_PART_BYTES:
        raise ValueError(f"{name} is too large")
    return ET.fromstring(archive.read(name))


def text_of(node: ET.Element) -> str:
    return "".join(t.text or "" for t in node.iter(f"{{{NS['m']}}}t"))


def load(path: str) -> dict:
    """{sheet name: {cell reference: (kind, text)}} for every sheet of the workbook."""
    with zipfile.ZipFile(path) as archive:
        shared = []
        if "xl/sharedStrings.xml" in archive.namelist():
            shared = [text_of(si) for si in read_part(archive, "xl/sharedStrings.xml").findall("m:si", NS)]
        workbook = read_part(archive, "xl/workbook.xml")
        rels = {r.get("Id"): r.get("Target") for r in read_part(archive, "xl/_rels/workbook.xml.rels").findall("rel:Relationship", NS)}
        sheets = {}
        for sheet in workbook.find("m:sheets", NS).findall("m:sheet", NS):
            target = rels[sheet.get(f"{{{NS['r']}}}id")].lstrip("/")
            part = target if target.startswith("xl/") else "xl/" + target
            cells = {}
            for cell in read_part(archive, part).iter(f"{{{NS['m']}}}c"):
                kind, text = cell_value(cell, shared)
                if text != "":
                    cells[cell.get("r")] = (kind, text)
            sheets[sheet.get("name")] = cells
        return sheets


def cell_value(cell: ET.Element, shared: list) -> tuple:
    kind = cell.get("t", "n")
    if cell.find("m:f", NS) is not None:
        return ("formula", "")
    if kind == "s":
        return ("text", shared[int(cell.find("m:v", NS).text)])
    if kind == "inlineStr":
        return ("text", text_of(cell.find("m:is", NS)))
    value = cell.find("m:v", NS)
    if value is None or value.text is None:
        return ("empty", "")
    if kind == "str":
        return ("text", value.text)
    if kind == "n":
        return ("number", repr(float(value.text)))
    return (kind, value.text)


def rows_of(cells: dict) -> list:
    """The sheet as a sorted list of rows (each row a sorted list of (column, kind, text)), for a comparison that ignores the order of rows."""
    rows = {}
    for ref, (kind, text) in cells.items():
        column = ref.rstrip("0123456789")
        rows.setdefault(int(ref[len(column):]), []).append((column, kind, text))
    return sorted(sorted(row) for row in rows.values())


def kept_rows(cells: dict, keep: tuple, ignore: set) -> list:
    """The rows whose cell in column keep[0] starts with keep[1] (row numbers dropped, the ignored columns left out): for callers who also see each side's own seed data."""
    rows = {}
    for ref, (kind, text) in cells.items():
        column = ref.rstrip("0123456789")
        rows.setdefault(int(ref[len(column):]), {})[column] = (kind, text)
    wanted = [r for _, r in sorted(rows.items()) if r.get(keep[0], ("", ""))[1].startswith(keep[1])]
    return [{c: v for c, v in r.items() if c not in ignore} for r in wanted]


def main() -> int:
    args = sys.argv[3:]
    unordered = "--unordered" in args
    keep = None
    ignore = set()
    if "--filter" in args:
        column, prefix = args[args.index("--filter") + 1].split(":", 1)
        keep = (column, prefix)
    if "--ignore" in args:
        ignore = set(args[args.index("--ignore") + 1].split(","))
    php, new = load(sys.argv[1]), load(sys.argv[2])
    problems = []
    if list(php) != list(new):
        problems.append(f"sheet names differ: php={list(php)} new={list(new)}")
    for name in php.keys() & new.keys():
        if keep is not None:
            a, b = kept_rows(php[name], keep, ignore), kept_rows(new[name], keep, ignore)
            if not a:
                problems.append(f"{name}: no row of the php file matches the filter (nothing was compared)")
            if a != b:
                problems.append(f"{name}: the rows matching the filter differ: php={a[:3]} new={b[:3]}")
            continue
        if unordered:
            if rows_of(php[name]) != rows_of(new[name]):
                problems.append(f"{name}: the rows differ (compared without their order)")
            continue
        for ref in sorted(php[name].keys() | new[name].keys()):
            a, b = php[name].get(ref), new[name].get(ref)
            if a != b:
                problems.append(f"{name}!{ref}: php={a} new={b}")
    for line in problems[:20]:
        print(line)
    cells = sum(len(kept_rows(c, keep, ignore)) if keep else len(c) for c in php.values())
    print(("DIFFERENT" if problems else "SAME") + f": {len(php)} sheet(s), {cells} php cell(s), {len(problems)} difference(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

"""Check repository documentation links without depending on remote services."""

from pathlib import Path
import re
from urllib.parse import unquote, urlsplit


ROOT_DOCUMENTS = ("README.md", "CHANGELOG.md", "ARCHITECTURE.md", "CONTRIBUTING.md")
REPOSITORY_PATH = "/leehack/genkit-llamadart/blob/main/"


def prose(markdown):
    return re.sub(r"(?ms)^\s*(`{3,}|~{3,})[^\n]*\n.*?^\s*\1\s*$", "", markdown)


def anchors(markdown):
    counts, result = {}, set()
    for match in re.finditer(r"(?m)^#{1,6}\s+(.+?)\s*#*\s*$", prose(markdown)):
        slug = re.sub(r"[^\w\- ]", "", match[1].lower()).replace(" ", "-")
        count = counts.get(slug, 0)
        result.add(f"{slug}-{count}" if count else slug)
        counts[slug] = count + 1
    result.update(re.findall(r'<a\s+(?:id|name)=[\"\']([^\"\']+)', markdown))
    return result


def destinations(markdown):
    text = prose(markdown)
    inline = re.findall(r"\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)", text)
    references = re.findall(r"(?m)^\s*\[[^]]+\]:\s*(<[^>]+>|\S+)", text)
    return [value.strip("<>") for value in inline + references]


def check_links(root, document):
    errors = []
    for destination in destinations(document.read_text()):
        url = urlsplit(destination)
        if url.scheme or url.netloc:
            if url.netloc != "github.com" or not url.path.startswith(REPOSITORY_PATH):
                continue
            target = root / unquote(url.path[len(REPOSITORY_PATH):])
        else:
            target = document.parent / unquote(url.path) if url.path else document
        if not target.is_file():
            errors.append(f"{document.relative_to(root)}: missing target {destination}")
        elif url.fragment and target.suffix == ".md":
            if unquote(url.fragment) not in anchors(target.read_text()):
                errors.append(f"{document.relative_to(root)}: missing anchor {destination}")
    return errors


def documents(root):
    return [root / name for name in ROOT_DOCUMENTS] + sorted([
        *root.glob("doc/**/*.md"), *root.glob("skills/**/*.md"),
    ])


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    files = documents(root)
    errors = [error for document in files for error in check_links(root, document)]
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"Documentation links and anchors pass in {len(files)} files; external URLs are not fetched.")

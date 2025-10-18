#!/usr/bin/env bash
set -euo pipefail

echo "Checking repository for files with shebang but missing executable bit..."
failures=0
while IFS= read -r file; do
  if [ ! -x "$file" ]; then
    echo "NON-EXECUTABLE: $file"
    failures=$((failures+1))
  fi
done < <(git grep -l "^#!" -- "**/*" || true)

if [ "$failures" -ne 0 ]; then
  echo "Found $failures non-executable script(s). To fix, run: git update-index --chmod=+x <file> and commit."
  exit 2
fi

echo "All script files with shebang are executable"
#!/usr/bin/env bash
set -euo pipefail

echo "Checking repository for files with shebang but missing executable bit..."
failures=0
while IFS= read -r file; do
  if [ ! -x "$file" ]; then
    echo "NON-EXECUTABLE: $file"
    failures=$((failures+1))
  fi
done < <(git grep -l "^#!" -- "**/*" || true)

if [ "$failures" -ne 0 ]; then
  echo "Found $failures non-executable script(s). To fix, run:' git update-index --chmod=+x <file>' and commit."
  exit 2
fi

echo "All script files with shebang are executable"

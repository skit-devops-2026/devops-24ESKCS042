#!/bin/sh
# Automated test suite for the Blood Bank Management System.
#
# Usage:
#   bash tests/test_project.sh
#       Check the files in the working tree (developer laptop, CI runner, Jenkins).
#
#   sh /opt/bloodbank/tests/test_project.sh /usr/share/nginx/html
#       Check the files as they actually exist inside the built image. This is what
#       the CI pipeline runs, so the artefact that ships is the artefact verified.
#
# Written in POSIX sh rather than bash so the identical suite runs on a Windows
# machine, on a GitHub Actions runner, and inside nginx:alpine, which does not ship
# Bash. `set -e` means a failing check fails the suite and turns the CI run red.

set -e

ROOT="${1:-.}"
cd "$ROOT"

echo "Running Blood Bank project tests against '$ROOT'"

# Test 1: main HTML file exists
test -f index.html
echo "PASS: index.html exists"

# Test 2: stylesheet exists
test -f css/style.css
echo "PASS: css/style.css exists"

# Test 3: HTML contains the main document structure
grep -q "<html" index.html
grep -q "<head" index.html
grep -q "<body" index.html
echo "PASS: HTML document structure is present"

# Test 4: page contains blood bank related content
grep -qi "blood" index.html
echo "PASS: Blood bank content is present"

# Test 5: HTML contains a page title
grep -q "<title>" index.html
echo "PASS: Page title is present"

# Test 6: HTML links the stylesheet
grep -q "css/style.css" index.html
echo "PASS: Stylesheet is linked correctly"

# Test 7: the blood group compatibility table is present
grep -q "<table" index.html
grep -qi "AB+" index.html
echo "PASS: Blood group compatibility table is present"

echo
echo "All Blood Bank project tests passed!"

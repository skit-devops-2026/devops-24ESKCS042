# Testing Guide

The Blood Bank Management System uses a simple automated shell test suite. It has no external
dependencies, so it runs identically on a developer laptop, on a GitHub Actions runner, and
inside the Docker image.

## Running the tests

```bash
make test
```

or directly:

```bash
bash tests/test_project.sh
```

## What is covered

The suite checks that:

1. `index.html` exists
2. `css/style.css` exists
3. `index.html` contains a well-formed document structure (`<html>`, `<head>`, `<body>`)
4. `index.html` contains blood bank specific content
5. `index.html` contains a page title
6. `index.html` links the stylesheet

## Running the tests inside the container

The same suite is executed against the built image by the CI pipeline, so the artefact that ships
is the artefact that is verified:

```bash
docker build -t bloodbank .
docker run --rm bloodbank sh /usr/local/bin/run-tests.sh
```

The script is POSIX `sh`, so it runs on Alpine-based images that do not ship Bash.

## Adding tests

Add assertions to `tests/test_project.sh`. The first command in the script is `set -e`, so a
failing check fails the suite and turns the CI run red. Keep assertions meaningful — the milestone
sheet is explicit that a placeholder test will pass an automated scanner and fail the viva.

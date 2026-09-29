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
sh tests/test_project.sh
```

## What is covered

The suite checks that:

1. `index.html` exists
2. `css/style.css` exists
3. `index.html` contains a well-formed document structure (`<html>`, `<head>`, `<body>`)
4. `index.html` contains blood bank specific content
5. `index.html` contains a page title
6. `index.html` links the stylesheet
7. `index.html` contains the blood group compatibility table

The suite takes an optional root directory as its first argument, which defaults to the
repository root. That is what lets the identical script test the working tree locally and the
built image in CI.

## Running the tests inside the container

The same suite is executed against the built image by the CI pipeline, so the artefact that ships
is the artefact that is verified:

```bash
docker build -t bloodbank .
docker run --rm bloodbank sh /opt/bloodbank/tests/test_project.sh /usr/share/nginx/html
```

The script is POSIX `sh`, so it runs on Alpine-based images that do not ship Bash.

Note the argument. It points the suite at `/usr/share/nginx/html`, the directory the application
is actually served from inside the container, rather than at a copy of the source somewhere else.
That is what makes the result meaningful: a green run here is evidence about the artefact that
ships, not about the repository that built it.

The image's `CMD` is `nginx`, so passing a command overrides it for that single run and the image
is left unchanged.

## Adding tests

Add assertions to `tests/test_project.sh`. The first command in the script is `set -e`, so a
failing check fails the suite and turns the CI run red. Keep assertions meaningful — the milestone
sheet is explicit that a placeholder test will pass an automated scanner and fail the viva.

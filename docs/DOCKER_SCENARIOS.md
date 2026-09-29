# Docker Scenarios — answers and what they mean here

Twelve situations from the Docker scenarios sheet, answered from first principles and then tied
back to this repository.

These are written as answers, not as a transcript of the sheet. Where a scenario assumes a Node
application with MongoDB, and this project is a static nginx site with no database, that is called
out explicitly rather than papered over with a parallel that does not exist.

The three situations most worth understanding properly are **2** (image size), **11** (registry
auth) and **12** (floating tags). Those are the ones that cause real outages and the ones that are
easiest to get wrong on the first attempt.

---

## Part 1: Images and containers

### 1. The image built, but nothing happens

`docker build` succeeds, `docker run` produces no errors, the terminal just sits there, and
`localhost` times out.

**What was forgotten: publishing the port.** The build and the port are unrelated decisions.
Building an image means Docker successfully assembled a filesystem. Nothing has been decided
about how that filesystem is reachable. A container is its own network namespace, so nginx
listening on port 80 *inside the container* is listening on port 80 of a private virtual
interface. Your browser is on the host's network stack and has no route there. You need
`-p 8081:80` to bridge them.

A successful build therefore guarantees nothing about reachability. It is a statement about an
artefact, not about network topology.

**In this repo:** `docker-compose.yml` publishes `8081:80`, and the file comment says so
explicitly, because this is the single easiest thing to get wrong on a static site — the image is
healthy, the app is serving, and it is still invisible. The compose file's header comment treats
the port mapping as the thing you must not delete.

To confirm the app is fine and merely unexposed, without restarting anything:

```bash
docker exec -it bloodbank sh
wget -qO- localhost/
```

### 2. Same Dockerfile, wildly different image sizes

Two people build from what looks like the same `Dockerfile`; one gets 180 MB, the other 1.2 GB.

**First thing to check: does a `.dockerignore` exist in their folder at all?** This is almost
always the cause. Without one, `docker build` ships the entire working directory to the daemon as
build context, and `COPY . .` bakes all of it into a layer. A local `node_modules` is the classic
culprit: `npm install` inside the image creates a fresh one, and then `COPY . .` copies the host's
much larger one over the top of it, so the image carries both.

To find the real source rather than guess:

```bash
docker history todo-practice     # size added by each instruction, oldest layer last
docker exec -it <container> sh
du -sh node_modules              # for the in-container version
```

`docker history` is the diagnostic that matters. It attributes bytes to specific instructions, so
it turns "the image is too big" into "instruction 4 added 900 MB".

**In this repo:** `.dockerignore` exists and excludes `.git`, `*.pdf`, `.github`, `k8s`,
`monitoring`, `docs`, `.env` (with `!.env.example` kept), dependency directories, build output and
editor noise. It also lists `node_modules` and `venv` even though neither is needed today,
specifically to guard against them reappearing locally later and silently inflating the context.

The `Dockerfile` then uses three explicit `COPY` instructions rather than `COPY . .`, so
`.dockerignore` is belt and braces: even a correct ignore file cannot protect a build if a
maintainer later adds a file and a `COPY . .`.

One deliberate consequence: `tests/` is *not* in `.dockerignore`, because the `Dockerfile` copies
it to `/opt/bloodbank/tests/` so CI can test the shipped artefact. It is small and it earns its
place.

### 3. It worked five minutes ago

You edit the HTML, rebuild, run, refresh, and see the old version.

**You rebuilt the image but did not replace the container.** A running container keeps running
the filesystem it was created from. Building a new image under the same tag does not touch
containers that already exist — it just creates a new image object. Your old container is still
serving the old layer, and it still answers on the port.

```bash
docker ps                                   # look first; the old one is probably there
docker stop todo-solo && docker rm todo-solo
docker run -p 5000:5000 --name todo-solo todo-practice
```

`docker rm` is the part people skip. `docker stop` leaves the container on disk in `Exited` state,
and because the name is taken the next `docker run --name` fails outright.

**In this repo:** CI sidesteps this entirely by running a throwaway container
(`docker run --rm bloodbank:ci ...`) for tests and never relying on a long-lived container. The
long-lived ones are the Pages deployment and any local `docker compose up`, which the
`--build` flag handles.

### 4. The build takes 40 seconds for a one-line HTML change

**Check the order of the instructions in the `Dockerfile`.** Docker caches the result of each
instruction and reuses it as long as nothing above it changed. So if `COPY . .` appears near the
top — before `npm install` — then *any* file change, including one to `index.html`, invalidates
that layer and every layer after it. You get a full dependency reinstall for a two-word edit.

The fix is the standard ordering: copy the dependency manifest first, install, *then* copy the
rest of the source. The expensive, rarely-changing step is cached; the cheap, frequently-changing
step is not.

You can prove it to yourself: reorder the `Dockerfile` so `COPY . .` precedes `npm install`, build
twice with a small HTML edit between the builds, and watch the second build take as long as the
first.

**In this repo there is no install step at all**, so this failure mode cannot occur as described.
The closest equivalent is layer ordering in a three-instruction `Dockerfile`: `COPY index.html`,
`COPY css/`, `COPY tests/`. Each is its own cached layer, so touching `index.html` invalidates
only the first. Nginx is pulled as a single base layer and nothing is installed at build time.

The general lesson still holds, and it is the reason the `Dockerfile` does not do
`COPY . /usr/share/nginx/html` and unpack it in one shot. Explicit per-path copies keep the
cache useful. If this project ever gains a build step, the ordering rule applies unchanged.

---

## Part 2: Networking and docker compose

### 5. A standalone container cannot reach the database

The app runs alone and logs `ECONNREFUSED 127.0.0.1:27017`.

**Would a separately-started MongoDB container be reachable just because both are running? No.**
Two containers on the same machine are not automatically visible to each other. Each gets its own
network namespace by default, and `localhost` inside a container means *that container*. Not your
laptop, not the other container. `127.0.0.1:27017` inside the app container is the app container's
own loopback, where nothing is listening.

To connect two manually-started containers you must put both on the same user-defined network and
address the peer by **container name**, which Docker's embedded DNS resolves:

```bash
docker network create app-net
docker run -d --network app-net --name db mongo:6
docker run -d --network app-net -p 8081:80 --name bloodbank bloodbank
```

**In this repo:** there is no database, so there is no `db` service and no cross-container
networking to misconfigure. The compose file has a single service. That is a genuine architectural
difference, not an oversight — the app is static HTML and CSS served by nginx, and all the data in
`index.html` is checked into the repository.

Worth being explicit about, though: the moment this project gains a backend, the "single service"
convenience stops applying and every rule in this section becomes live. A container's `localhost`
is always itself, and Compose service names only resolve on a Compose-created network.

### 6. Compose works, manual `docker run` does not, with the same image

**Compose creates a dedicated network for the project and attaches every service to it.** On that
network, each service is reachable by its service name, so `db` resolves to the database
container's IP via Docker's embedded DNS. You configure no networking yourself.

```bash
docker network ls          # a <folder-name>_default network now exists
docker network inspect <folder-name>_default
```

Containers started with plain `docker run` land on the generic `default` bridge instead. On that
network they can technically reach each other by IP address, but **not by name** — there is no
automatic name resolution. That asymmetry is the whole difference: Compose's network is
purpose-built and name-aware, and the default bridge is neither.

**In this repo:** Compose is used for convenience (port mapping, healthcheck, restart policy)
rather than because of multi-service DNS, since there is one service. The two still differ
observably: `docker compose up` attaches to a project-scoped network, a bare `docker run` does not.

### 7. "Port is already allocated"

`Bind for 0.0.0.0:5000 failed: port is already allocated`.

**Something on the machine already holds the port, and it is almost certainly the earlier manual
container you forgot about**, not a Compose problem. Find it with:

```bash
docker ps                 # every running container, with its port mappings
```

Look for anything with your port next to it, then `docker stop` and `docker rm` it. This is
rarely Docker being wrong; the error is honest.

**In this repo:** the port is `8081`, and the same failure mode applies. `docker compose down`
handles the Compose-managed container, but a container started earlier by hand will not be
cleaned up by it, which is exactly how the situation arises.

### 8. A teammate hardcodes the Mongo URL

Someone replaces `process.env.MONGO_URL || "mongodb://localhost:27017/todos"` with the bare
literal. It works on their laptop via `node server.js`, and breaks under Compose.

**Because `localhost` changes meaning between the two contexts.** On their laptop,
`localhost:27017` is correct — they have Mongo installed locally, or running as a container with
its port published to the host, so the host's `localhost` really is the database. Inside the app
container under Compose, `localhost` becomes the app container itself, and there is no Mongo in
there.

The environment variable exists precisely to absorb that difference: the same code points at
`localhost` outside Docker and at `db` inside it, with no per-situation edit. Hardcoding it
destroys that flexibility, and specifically breaks the Compose case, because `db` — service-name
resolution on a Compose network — was the entire fix for question 5.

**In this repo:** no database, so no connection string to hardcode. The equivalent lesson is about
**build-time versus runtime configuration**, and the repository does take it seriously: `.env` and
`.env.*` are excluded in `.dockerignore` while `!.env.example` is explicitly kept, so a real
secret can never be baked into an image layer.

---

## Part 3: Data and volumes

### 9. All the to-dos disappeared after a routine restart

`docker-compose down` then `docker-compose up`, and the list is empty.

**With the `mongo-data` named volume in place, this should not happen.** `down` without `-v`
removes containers and networks but leaves named volumes in place, so the data should still be
there on the next `up`. If it did get wiped, the cause is one of exactly two things:

- `docker-compose down -v` was used by accident. The `-v` flag deletes volumes too, and it is
  trivially easy to type without noticing.
- The `volumes:` section is missing from the compose file entirely, so the database is writing
  into the container's own writable layer.

```bash
docker volume ls      # run this right after down, before the next up
```

If `mongo-data` is missing from that list, that is your answer.

**In this repo there is no data to lose, and the reason is architectural.** The application is a
static site; all of its content lives in `index.html` and is version controlled. Recreating a
container changes nothing, because there is no runtime state. Deleting a container is genuinely
harmless here, not merely survivable.

That is worth stating as a property rather than leaving implicit: the app is stateless, so it
scales horizontally without coordination and needs no volume. It also means it cannot support
features requiring server-side persistence — donors, appointments, inventory — without adding a
backend and, with it, a real volume.

### 10. Two people, two very different experiences with the same file

One teammate deletes and recreates the `db` container constantly with no data loss. Another does
the same thing on a project with no named volume and loses everything.

**The single line responsible:**

```yaml
volumes:
  - mongo-data:/data/db
```

**Without it**, MongoDB writes into the container's writable layer, which exists only for as long
as that specific container. Delete the container and the data goes with it, image and all. **With
it**, `/data/db` is redirected to storage Docker manages outside any single container's lifecycle;
`mongo-data` survives deletion and recreation, and is removed only if you explicitly delete the
volume or pass `down -v`.

This is the single most common cause of "I lost all my data" with any containerised database, and
it is always the same missing line.

**In this repo:** not applicable, and for the same reason as question 9 — the app is static and
holds no runtime state. `docker-compose.yml` has no `volumes:` section because adding an empty one
would imply a persistence requirement that does not exist. The lesson transfers to any future
backend: the moment stateful data is introduced, a named volume is not optional.

---

## Part 4: Getting it out into the real world

### 11. Push fails with "unauthorized"

`unauthorized: unauthenticated: User cannot be authenticated with the token provided`, and
`docker login` definitely worked earlier in the week.

**Two realistic causes, neither related to your code:**

1. **The token expired.** GitHub personal access tokens have an expiry date. Sessions established
   before expiry do not renew themselves — you need a new token with `write:packages` and another
   `docker login`.
2. **A typo in the image tag.** This is the more common one and the more confusing, because GitHub
   reports a naming problem as an authentication failure. The tag must include your exact
   username in the right position:

   ```
   ghcr.io/yourusername/todo-practice      correct
   ghcr.io/todo-practice                   wrong, no namespace
   ghcr.io/your-username/todo-practice     wrong, username misspelled
   ```

   Without the namespace, GitHub has no way to know whose packages you are pushing to.

Check `docker images` for the exact tag you built before assuming the login is broken.

**This is not hypothetical — it is the real failure mode in this repository**, and it is why the
registry namespace is worth understanding. The practice sheet suggests:

```yaml
ghcr.io/${{ github.actor }}/...
```

which would publish to `ghcr.io/amisha-2403/...` — a *personal* namespace. But `GITHUB_TOKEN` is
scoped to this repository, which lives under the `skit-devops-2026` organisation, so pushing into
the personal namespace is rejected. The workflow uses `github.repository_owner` instead, which
resolves to `skit-devops-2026` and is already lowercase, as GHCR requires.

A third cause applies specifically to CI and is handled by the `if: github.event_name == 'push'`
gate on the push step: `GITHUB_TOKEN` is **read-only** on pull requests from forks, so a PR must
not attempt to push. Build and in-container test still run, so a PR is still fully verified.

### 12. It works on your machine, breaks for your evaluator

`FROM node:latest` instead of `node:18-alpine`. Worked for a month, then fails on someone else's
machine at `npm install` with an unfamiliar dependency error.

**`latest` is not a version. It is a moving target that means "whatever is newest at the moment
this image is built".** The reason it worked for a month is a cache artefact, not a property of
the Dockerfile: the locally cached older Node image kept satisfying the build, so nothing new was
ever pulled. An evaluator, a CI server, or anyone building fresh pulls whatever `latest` points
at today, which may be a newer major Node release with breaking changes.

Pinning to `node:18-alpine` means everyone, every time, gets the same Node. That is the entire
reason for pinning, and it is not a stylistic preference.

**In this repo:** `FROM nginx:1.27-alpine`, not `nginx:alpine`. This is scenario 12 applied. The
existence of the `1.27-alpine` tag was verified against Docker Hub before it was used, because a
pin to a tag that does not exist is a different failure with the same root cause — an unverified
floating reference.

Note that the Kubernetes manifest has a *related* tension, and it is deliberate.
`k8s/deployment.yaml` uses `:latest` with `imagePullPolicy: Always` so a cluster picks up the
newest successful build without a manifest edit. That is a deployment convenience, not a
reproducibility guarantee, and it is the same trap as scenario 12 in a different place. For
anything that must behave reproducibly, the commit-SHA tag that CI also publishes is the
correct choice, paired with `imagePullPolicy: IfNotPresent`. The manifest header documents the
trade-off rather than leaving it implicit.

---

## What actually distinguishes this repository

Two habits, applied consistently:

**Everything shipped is verified by pulling it back.** The CI pipeline builds the image, runs the
test suite *inside* it against `/usr/share/nginx/html`, pushes to GHCR, and then pulls the tag
back and prints the digest the registry reports. A zero exit code from `docker push` is not proof
a usable image exists — a tag can be created while the manifest beneath it is wrong. See
[deployment.md](deployment.md).

**The image is stateless, deliberately.** A static site with checked-in content has no runtime
state, so it needs no database, no volume, and no cross-container networking. Questions 5, 6, 8,
9 and 10 above are therefore about a shape this project does not have. That is a design
consequence, not an oversight, and the honest summary of what those five questions teach is:
the moment server-side state is introduced, all five concerns become live at once.

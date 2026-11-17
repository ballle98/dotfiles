# openHAB DDWRT Binding Workspace Agent Context

Context for [`~/git/dotfiles/vscode/workspaces/org.openhab.binding.ddwrt.code-workspace`](../../vscode/workspaces/org.openhab.binding.ddwrt.code-workspace).

Status: created 2026-11-16 from the workspace file alone. The sibling checkouts were not
inspected, so the host/build facts below are **unverified** until the checks in the next
section are run and recorded here.

## Included Projects (multi-root)

- `~/git/openhab-addons/bundles/org.openhab.binding.ddwrt` - binding source, workspace
  folder `addons-ddwrt`
- `~/git/openhab-distro/launch/app` - openHAB distro app used to run and debug the
  binding, workspace folder `distro-app`
- `~/git/dotfiles/agents/org.openhab.binding.ddwrt` - this folder (added to the
  workspace); durable context plus handoffs

The workspace paths are relative (`../../../openhab-addons/...`,
`../../../openhab-distro/...`), so they only resolve when `openhab-addons`,
`openhab-distro`, and `dotfiles` are siblings under `~/git/`.

## Verify on First Session

Read-only checks; fold the results back into this file:

```bash
java -version
~/git/openhab-addons/mvnw -v
git -C ~/git/openhab-addons status -sb
git -C ~/git/openhab-distro status -sb
command -v nc            # required by the `Maven app debug` task
ls ~/git/openhab-addons/bundles/org.openhab.binding.ddwrt
```

Check which JDK the checked-out branch expects (`pom.xml`, `.github/workflows/`, or the
developer docs) instead of assuming 17 or 21. Note the binding's branch and whether the
checkout has local changes before reporting a build result.

## Building the Binding (openhab-addons)

Every build task runs `./mvnw` with cwd `~/git/openhab-addons` (the bundle's `../..`),
targeting `-pl :org.openhab.binding.ddwrt`:

- `Maven Install` - default build task: `install -fae
  -Dmaven.compiler.failOnError=false`
- `Maven Install kar` - `install karaf:kar -DskipTests -DskipChecks`
- `Maven clean install` - `clean install -fae -Dmaven.compiler.failOnError=false`
- `Maven clean install (with updates)` - `clean install -U`
- `Maven skip checks install` - see the gotcha about `-f ../../pom.xml`
- `mvn Spotless (Fix codestyle)` - `spotless:apply`
- `Maven CI Verify` - `clean verify -B -T 1.5C -U -am -amd` with the `-pl` list that
  includes the BOM/index modules and excludes the features/karaf modules
- `Full github CI Build` - `./.github/scripts/maven-build`; slow, run only when asked

Output lands in the bundle's `target/`; `view code analysis report` opens
`target/code-analysis/report.html` with `xdg-open`.

## Run and Debug (openhab-distro/launch/app)

These tasks invoke `~/git/openhab-distro/mvnw -f
~/git/openhab-distro/launch/app/pom.xml`:

- `Maven app resolve` - `bnd-resolver:resolve`; useful after a resolution failure
- `Maven app run` / `Maven app clean run` - `bnd-run:run` / `clean bnd-run:run`
- `Maven app debug` - background task: `-D-runjdb=10001 bnd-run:run`, waits for
  `localhost:10001` with `nc`, prints `OPENHAB_DEBUG_READY`; the `Attach to openHAB`
  launch configuration then attaches to `localhost:10001`
- `reset userdata` - `rm -rf ${workspaceFolder:distro-app}/runtime/userdata/*`;
  destructive, confirm you are on the dev distro before running it

## Gotchas / Tips

- `Maven skip checks install` sets cwd to `~/git/openhab-addons` but passes
  `-f ../../pom.xml`, which resolves to `~/pom.xml`. Drop the `-f` or fix the path before
  trusting that task.
- `Export full git diff with timestamp` uses `git merge-base @{u} HEAD`, so the branch
  needs an upstream. It writes `full-diff-<mm-dd-yy_hh-mm-ss>.txt` into the task cwd
  (the openhab-addons root).
- `Version timestamp` is just `date +%Y%m%d%H%M`, handy for build labels.
- `git.alwaysSignOff` is enabled and the Java formatter comes from the openHAB code
  style URL in the workspace settings. Java stays at 4-space indent; do not turn on
  `detectIndentation`.
- Handoffs: `handoffs/YYYY-MM-DD-HHMM-<topic>.md` (see `handoffs/README.md`); record
  branches, commands run, failures, and next steps, then fold durable facts back into
  this file.
- Don't commit secrets or keys. Follow `~/git/dotfiles/AGENTS.md`.

## Quick Links

- Workspace: `~/git/dotfiles/vscode/workspaces/org.openhab.binding.ddwrt.code-workspace`
- Binding checkout: `~/git/openhab-addons/bundles/org.openhab.binding.ddwrt`
- openHAB command-line build:
  https://github.com/openhab/openhab-addons#command-line-build
- openHAB IDE setup:
  https://www.openhab.org/docs/developer/ide/generic.html#preparation

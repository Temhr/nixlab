# ContainerRestartLoop

**What it means.** A container (the `name` label) has restarted more than twice in 15 minutes. This alert only exists when the container (cAdvisor) integration is enabled.

**Likely causes.** The application crashes on start; a bad configuration or missing volume or secret; it is killed for exceeding its memory limit; a failing healthcheck.

**First three commands.**
1. `docker ps -a --filter name=<name>` (or `podman ps -a`)
2. `docker logs --tail 80 <name>`
3. `docker inspect <name> --format '{{.State.ExitCode}} OOM={{.State.OOMKilled}}'`

**Fix.** Fix the cause in the logs, raise the memory limit if it was OOM-killed, or roll back the last image or config change.

**Escalate when.** It keeps looping after a rollback, or a database container is involved (risk of corruption).

**Related alerts.** ContainerHighMemory, OutOfMemoryKills, SystemdServiceFailed.

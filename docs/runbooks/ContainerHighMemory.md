# ContainerHighMemory

**What it means.** A container (the `name` label) has used more than 90% of its configured memory limit for 5 minutes. This alert only exists when the container (cAdvisor) integration is enabled.

**Likely causes.** A memory leak; a workload that outgrew its limit; a limit that is set too low.

**First three commands.**
1. `docker stats --no-stream <name>`
2. `docker inspect <name> --format '{{.HostConfig.Memory}}'`
3. `docker logs --tail 50 <name>`

**Fix.** Raise the limit if the usage is legitimate, or find and fix the leak. Restart the container if it has grown steadily over time.

**Escalate when.** It is killed and restarted by the OOM killer (see ContainerRestartLoop).

**Related alerts.** ContainerRestartLoop, HighMemoryUsage, OutOfMemoryKills.

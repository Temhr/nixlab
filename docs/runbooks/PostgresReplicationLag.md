# PostgresReplicationLag

**What it means.** A PostgreSQL replica has been more than 5 minutes behind its primary for 5 minutes. This alert only exists when the `postgres` integration is enabled.

**Likely causes.** Network trouble between primary and replica; a replica that is overloaded or has slow disks; a long-running query on the replica blocking replay; a very large burst of writes on the primary.

**First three commands.**
1. On the primary: `sudo -u postgres psql -c 'SELECT client_addr, state, replay_lag FROM pg_stat_replication;'`
2. On the replica: `sudo -u postgres psql -c 'SELECT now() - pg_last_xact_replay_timestamp() AS lag;'`
3. `journalctl -u postgresql -n 50 --no-pager` on both hosts

**Fix.** Restore the network path, clear blocking queries on the replica, or give it more I/O capacity. If the lag keeps growing, check whether WAL files needed by the replica have been removed.

**Escalate when.** The replica has fallen further behind than the primary's retained WAL; it then needs a fresh base backup (`pg_basebackup`).

**Related alerts.** ProbeFailed, NetworkInterfaceErrors.

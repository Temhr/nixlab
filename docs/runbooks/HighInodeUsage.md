# HighInodeUsage

**What it means.** A filesystem has less than 20% of its inodes free. Once inodes run out, no new files can be created even if there is free space.

**Likely causes.** Millions of small files: caches, mail queues, build trees, container layers, session files; runaway temporary-file creation.

**First three commands.**
1. `df -i`
2. `sudo find <mountpoint> -xdev -type d -size +1M 2>/dev/null | head` (directories with huge entry lists)
3. `for d in <mountpoint>/*; do echo "$(sudo find "$d" -xdev | wc -l) $d"; done | sort -n | tail`

**Fix.** Remove the offending files or the process that creates them. If the filesystem was created with too few inodes, recreate it with more (ext4 `mkfs -i`).

**Escalate when.** It reaches near zero free inodes (writes will start failing).

**Related alerts.** LowDiskSpace, CriticalDiskSpace.

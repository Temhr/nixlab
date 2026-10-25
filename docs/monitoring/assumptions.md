0.5 Recorded S0 findings and decisions

Recorded 2026-10-24. Copy this section into docs/monitoring/assumptions.md (the S0 deliverable) and keep it current.

Fleet (from flake/data/hosts-meta.nix and the live hosts)
Host	Address	Ethernet	Wi-Fi	nixpkgs	Battery	Drives (smartctl)	Always-on	Planned role
nixnas1	10.0.0.251	eno1	none ("")	stable	no	NVMe + SAS/SCSI; ZFS pool tanks	yes	primary hub
nixnas2	10.0.0.252	eno1	wlp1s0 (also DHCP 10.0.0.218)	stable	no	ATA	yes	secondary hub; wired only
nixace	10.0.0.200	enp0s31f6	wlp3s0 (default route is Wi-Fi)	unstable	BAT0	NVMe + ATA	yes	agent
nixsun	10.0.0.201	enp0s25	wlo1 (default route is Wi-Fi)	unstable	BAT0	ATA	no	agent; canary
nixtop	10.0.0.202	enp0s25	wlp61s0 (also DHCP 10.0.0.205)	unstable	BAT0	ATA	no	agent
nixvat	10.0.0.203	enp0s25	wlo1 (default route is Wi-Fi)	unstable	none (a Logitech hidpp_battery_0 only)	ATA	no	agent
nixzen	10.0.0.204	enp0s25	wlp61s0 (default route is Wi-Fi)	unstable	BAT0	ATA	no	agent

Facts that hold for all seven (from mkHostMeta defaults and probe 14): gateway 10.0.0.1, prefix length 24, nameservers 9.9.9.9 and 1.1.1.1, system = x86_64-linux. Every host has systemUsers = [temhr guest]. hostsMeta.<h>.interfaces is derived as a list of {name, address, type} with type of "ethernet" or "wifi"; the Wi-Fi entry reuses the host's static address (it does not know about the extra DHCP addresses on nixtop and nixnas2).

Consequences:

wifiIface = "" is the "no Wi-Fi" sentinel (nixnas1). mkHostMeta already omits the Wi-Fi interface entry in that case.
Hubs are on stable, agents on unstable. Versions found: Prometheus 3.12.0 on both hubs, 3.15.0 on nixsun; ntfy 2.31.0 on nixsun (hubs open, probe 23). Stages that depend on version-specific behaviour must be checked on both channels.
nvidia-smi segfaults on all five GPU hosts, all unstable. The hubs have no GPU.
Four of five agents route over Wi-Fi, and nixtop and nixnas2 have a second, DHCP Wi-Fi address. Agent firewall rules must key on the hub's source address, not on an interface, and the address the hub scrapes (hostsMeta.address) must be the one that answers on whichever link is up.
mkHostMeta (in flake/schema/hosts.nix, an evalModules schema) has no monitoring fields yet; S45 adds a typed monitoring submodule.
Hub-affecting stages roll out nixsun, nixnas2, nixnas1, agents.
Progress tracker
Stage	Status
S0	Baseline green on nixsun, nixnas1, nixnas2; hub snapshots verified present; all probes answered. To close: commit assumptions.md and the scripts, tag mon-S0. nixace/nixtop/nixvat/nixzen have no baseline; not needed before S44
S9	Partly applied by hand on nixsun (helper unit only), uncommitted. See S9
S1 onward	Not started
Probe results
#	Probe	Result (2026-10-24)	Effect on the guide
1 / 16	getent group alertmanager; grep '^alertmanager:' /etc/group	getent: alertmanager:x:65343; grep: nothing	Dynamic-user group only. S11 bullet confirmed
2 / 17	Prometheus version	nixnas1 and nixnas2 3.12.0; nixsun 3.15.0	All 3.x and all run with the console flags. S6 item 1 is hygiene (D14)
3	unit EnvironmentFile?	EnvironmentFiles=/run/secrets/ALERTMANAGER_ENV	S3 confirmed; latent until a receiver uses a $VAR
4 / 23	ntfy version	nixsun 2.31.0; nixnas1 and nixnas2 2.26.0	Declarative users probably available; confirm with ntfy serve --help on a hub (S16)
5	smartctl metrics	per-host table in the capability matrix	NVMe, ATA and SAS names confirmed. S28 updated
6	timer metric	13 series on nixsun; 11 timers	S30 confirmed; timer table in S30
7	systemd-time-wait-sync	absent at 13:53, present at 14:10	Helper applied locally; per-service ordering not. S9 rewritten
8	uids per host	differ on every host (table below)	S23 pins and the reboot gotcha
9	nftables.enable	false	iptables rules in S44
10	Alloy metrics	loki_write_dropped_entries_total exists	S27 confirmed
11 / 15	nvidia-smi -L	segfault on nixsun, nixace, nixtop, nixvat, nixzen; the hubs have no GPU	GPU exporter off (D7)
12 / 13	hostsMeta, registry, hosts.nix	read; mkHostMeta schema known; gateway and nameservers exist	S15, S34, S44, S45 updated
14	default route	all via 10.0.0.1; Wi-Fi is the default route on nixsun, nixace, nixvat, nixzen; hubs and nixtop have wired metric-100 routes	D9, D10
15	battery	BAT0 on nixsun, nixtop, nixzen, nixace; none on hubs; nixvat has only hidpp_battery_0	S32 filter on BAT.*
15	ZFS	zpool list works only on nixnas1: pool tanks, 14.5 T, 17% used, ONLINE	S31 applies to nixnas1 only
15	always-on	nixace, nixnas1, nixnas2	D3
18	free uids 730 to 759	free on all hosts	D6
19	snapshots on hubs	present on both	closed
20	listeners and firewall (nixsun)	firewall enabled; listeners in the Exposure finding	S15 updated
22	what opens 9633, 9558, 9115?	nothing: allowedTCPPortRanges = [], trustedInterfaces = ["lo"], no per-interface rules, extraCommands is only the NAT cleanup helper, iptables -S nixos-fw matched none of the ports. In the default state curl <host>:9633 from nixsun hangs on nixtop, nixzen, nixnas1 and nixnas2	The earlier remote successes came from temporary settings, since reverted. Exporter ports are firewalled. S15 corrected
24	deployment automation	read -nixlab-gpull.nix and -nixos-upgrade.nix	Deployment model (R.3, section 0.4); D16

All S0 probes are answered. Probes 22 and 23 are the last two and are recorded in the table above. Later stages bring their own verification commands.

Exposure finding (corrected after probe 22)

listeners.txt on nixsun: bound to all interfaces *:2586 ntfy, *:3100 Loki, *:3101 Grafana, *:9090 Prometheus, *:9093 Alertmanager, *:9094 Alertmanager cluster gossip (no peers are configured, yet it listens), *:9096 Loki gRPC, *:9115 blackbox, *:9558 systemd exporter, *:9633 smartctl. Loopback only: 127.0.0.1:9100 node exporter, 127.0.0.1:12345 Alloy.

The firewall is enabled and allowedTCPPorts is 22, 2586, 3000, 3007, 3100, 3101, 9090, 9093, 9096, 9119, 11434, 27015, 27036, 27037, 27040. Nothing else opens ports (probe 22). Therefore:

Reachable from the LAN today: the monitoring ports 2586, 3100, 3101, 9090, 9093 and 9096 (Loki gRPC), all via openFirewall; plus, from other modules, 22, 3000, 3007, 9119, 11434 and the Steam ports.
Bound to all interfaces but firewalled: 9633, 9558, 9115 and 9094. This is a defence-in-depth gap (one firewall mistake from exposure), not a live hole. The remote responses seen earlier came from temporary settings that have since been reverted.
Consequence for the fleet design: nothing opens the exporter ports today, so the hub cannot scrape agents until S44 adds a source-restricted rule for 9100 and 9633.
Capability matrix
Host	Drives seen by smartctl	NVMe metrics	Battery	ZFS	Working nvidia-smi	Always-on
nixace	NVMe + ATA	yes	BAT0	no	no (segfault)	yes
nixsun	ATA only	no	BAT0	no	no (segfault)	no
nixtop	ATA only	no	BAT0	no	no (segfault)	no
nixvat	ATA only	no	none (mouse only)	no	no (segfault)	no
nixzen	ATA only	no	BAT0	no	no (segfault)	no
nixnas1	NVMe + SAS/SCSI	yes	none	yes (tanks)	no GPU	yes
nixnas2	ATA only	no	none	no	no GPU	yes

nixnas1 exposes SCSI counters (smartctl_scsi_grown_defect_list, smartctl_read_total_uncorrected_errors, smartctl_write_total_uncorrected_errors, the *_errors_corrected_* family) instead of smartctl_device_attribute and smartctl_device_error_log_count, so ATA reallocated-sector rules never match there. S28 carries SCSI rules for it.

Service uids/gids as found (uid/gid; attributed by the prompt hostname above each output)
Host	loki	alloy	grafana	prometheus	ntfy
nixsun	987/981	984/977	988/982	986/980	977/970
nixtop	990/988	995/993	991/989	989/986	980/975
nixvat	984/980	982/977	986/989	985/981	974/969
nixnas2	988/985	992/989	990/987	987/984	983/979
nixnas1	989/986	993/990	991/988	988/985	984/980
nixace	987/982	992/989	989/986	983/977	986/981
nixzen	987/981	984/977	988/982	986/980	978/971

nixzen matches nixsun on four of five services (only ntfy differs by one). All of them sit in 970 to 995, allocated downward from 999 in boot order, so a pin has to move every host.

1. Stage index
#	Stage	Depends	Risk	State
S0	Baseline, snapshots, assumption probes, check scripts	none	none	no
S1	Build-time config validation (promtool, amtool)	S0	low	no
S2	Rule unit-test harness	S1	low	no
S3	Alertmanager environment file actually loads	S0	low	no
S4	Alertmanager routing: inhibit rules, repeat, grouping	none	low	no
S5	Always-on self-health rules + probe-failure alerts	S2	low	no
S6	Prometheus unit cleanup (console flags, TasksMax, state dir, collectors)	none	low	no
S7	mkServiceHardening bug fixes	none	low	no
S8	nginx helper fixes	none	low	no
S9	Start-order after clock sync	none	low	no
S10	Prometheus TSDB guard (the Aug–Oct incident class)	S9	med	yes
S11	Module nits (ntfy SMTP/Firebase, dead group, stale docs)	none	low	no
S12	externalUrl options + publicHost	none	low	no
S13	host external label + ntfy message template	S12	low	no
S14	Loki gRPC bind and firewall	none	low	no
S15	Loopback-by-default + interface-scoped access	S12	high	no
S16	ntfy authentication end to end	S3, S12, S15	med	yes
S17	Prometheus tunables (intervals, size cap, stack passthrough)	none	low	no
S18	Loki/Alloy telemetry off + ingestion limits	none	low	no
S19	Grafana hygiene (env, datasource uids, Alertmanager datasource)	S12	low	no
S20	Grafana provisioning safety	S12, S19	med	no
S21	Opt-in extra hardening (helper only)	S7	low	no
S22	Enable extra hardening per service (22a–22f)	S21	med	no
S23	Pin service uids/gids	none	med	yes
S24	Cheaper permissions oneshot	none	low	no
S25	Port consolidation	none	low	no
S26	Alert noise tuning	S2	low	no
S27	Stack self-monitoring alerts	S2	low	no
S28	SMART / disk-health alerts	S2, S17	low	no
S29	Filesystem integrity alerts	S2	low	no
S30	NixOS lifecycle exporter + alerts	S2, S6	low	no
S31	ZFS pool alerts	S2, S29	low	no
S32	Laptop battery alerts	S2	low	no
S33	NVIDIA GPU exporter + alerts	S2	med	no
S34	Probe defaults and derived targets	S2, S17	med	no
S35	Journal transport label	none	low	no
S36	Loki long retention for maintenance log + logrotate	none	med	no
S37	Loki ruler + journal alerts	S35	med	no
S38	Extract maintenance-log into its own module	none	low	no
S39	Maintenance script fixes + permissions	S38	low	no
S40	checklist.nix as single source of truth	S38	low	no
S41	Maintenance metrics + overdue alerts	S2, S6, S40	low	no
S42	Extract Alloy into its own module	none	low	no
S43	Extract node exporter into its own module	S6	low	no
S44	role = full | agent	S42, S43	med	no
S45	Hub scrapes agents, host series label, HostDown semantics	S44, S15	high	no
S46	Watchdog heartbeat + mutual hub watch	S4, S45	med	no
S47	Dashboard JSON fixes + dashboard CI	none	low	no
S48	$host variable + fleet row	S45, S47	low	no
S49	New rows, maintenance-status panels, health-score fix	S28, S30, S35, S41, S47	low	no
S50	Runbooks + annotation + CI	S2	low	no
S51	Backups of stateful pieces	none	low	no
S52	NixOS VM integration test	S16	med	no
S53	README chapter + decision record on upstream wrappers	none	none	no

Phases: A baseline and safety nets (S0–S2) · B confirmed bugs (S3–S11) · C identity (S12–S13) · D exposure (S14–S16) · E defaults and hygiene (S17–S25) · F alert coverage (S26–S34) · G logs (S35–S37) · H maintenance loop (S38–S41) · I fleet (S42–S46) · J dashboards (S47–S49) · K docs, backups, tests (S50–S53).

Phases B and E are mostly order-independent. Phase I should not start before D.

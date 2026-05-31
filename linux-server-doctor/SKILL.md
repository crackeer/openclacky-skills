---
name: linux-server-doctor
description: 'Diagnose Linux server issues via SSH. Handles server health patrol checks, performance troubleshooting, log analysis, and security auditing. Use when user mentions: server problem, server down, health check, server slow, CPU high, out of memory, disk full, service not running, SSH diagnose, 服务器问题, 服务器诊断, 服务器排查, 巡检, 故障定位.'
disable-model-invocation: false
user-invocable: true
---

# Linux Server Doctor

A comprehensive Linux server diagnostic skill. Connects via SSH to run diagnostic commands, analyzes results, and produces a structured report with fix suggestions.

## Before You Start

Ask the user these things (if not already provided):

1. **Target server**: IP or hostname. If the user has an SSH config alias (e.g., `ssh my-server`), use that.
2. **Mode**: Patrol (comprehensive health check) or Troubleshoot (targeted diagnosis)
3. **Symptoms** (for Troubleshoot mode only): What's wrong — "website slow", "can't SSH", "disk seems full", "service X crashed", etc.

**SSH connection details — ask explicitly when the user only gives a bare IP** (no `user@host`, no SSH config alias, no `-p` flag):

- **Username**: Default to `root`. Most servers use `root` for administration; if the user has a different username they'll specify it.
- **Port**: Default to 22. Only ask if the connection fails — non-standard ports (e.g., 2222, 9002) are common in production.

If the user provides a full `ssh user@host -p NNNN` syntax or an SSH config alias, skip these questions — the command format is already clear.

SSH should Just Work — assume the user has `~/.ssh/config` or key-based auth set up. If SSH fails with "Permission denied", suggest `ssh-copy-id` or key permissions (one message max). If it asks for a password, offer to set up key auth with `ssh-copy-id` or proceed with password (user's choice). If connection fails on port 22 (connection refused/timeout), prompt the user: "Can't reach port 22 — are you using a different SSH port?"

## SSH Command Construction

Once you have the username, host, and port, construct SSH commands as:

```bash
ssh -p <port> <user>@<host> "<command>"
```

If the port is 22, you can omit `-p 22`. If the user provides a full SSH string (`ssh root@10.0.0.1 -p 9002`), use it verbatim. In all command templates below, `<target>` means the full `<user>@<host>` (with `-p <port>` if non-standard).

Always test the connection with a simple command first before running the full diagnostic suite:
```bash
ssh -p <port> <user>@<host> "uname -a; uptime"
```

## Mode 1: Patrol (健康巡检)

Run a comprehensive health report covering all dimensions. Execute ALL checks below and compile findings.

### Check Categories

Execute commands in order. For each category, collect output, analyze for anomalies, and note findings.

**A. System Overview**
```bash
ssh <target> "uname -a; uptime; cat /etc/os-release 2>/dev/null | head -5"
```
- Note OS, kernel version, uptime. Uptime < 1 day → recent reboot, flag it.

**B. CPU & Load**
```bash
ssh <target> "echo '=== LOAD ==='; uptime; echo '=== TOP CPU ==='; ps aux --sort=-%cpu | head -6; echo '=== CPU COUNT ==='; nproc"
```
- Load average > CPU cores = overload. Note the top CPU-consuming process.

**C. Memory**
```bash
ssh <target> "free -h; echo '=== TOP MEM ==='; ps aux --sort=-%mem | head -6"
```
- Available memory < 20% total → warning. Check for OOM: `dmesg | grep -i 'out of memory' | tail -5`.

**D. Disk**
```bash
ssh <target> "df -h --exclude-type=tmpfs --exclude-type=devtmpfs; echo '=== INODES ==='; df -i --exclude-type=tmpfs --exclude-type=devtmpfs"
```
- Any partition > 85% → warning. > 95% → critical. Inode exhaustion is rare but equally fatal — flag if > 90%.

**E. Network**
```bash
ssh <target> "echo '=== LISTENING ==='; ss -tlnp 2>/dev/null | head -20; echo '=== CONNECTIONS ==='; ss -s"
```
- Note unusual listening ports. Too many TIME_WAIT connections → possible issue.

**F. Services**
```bash
ssh <target> "echo '=== FAILED SERVICES ==='; systemctl list-units --state=failed 2>/dev/null; echo '=== KEY SERVICES ==='; systemctl is-active sshd nginx apache2 docker k3s 2>/dev/null"
```
- Flag any failed units. Note if key services are inactive.

**G. Recent System Logs**
```bash
ssh <target> "echo '=== DMESG ERRORS ==='; dmesg --level=err,warn 2>/dev/null | tail -20; echo '=== JOURNAL ERRORS (last 1h) ==='; journalctl -p err --since '1 hour ago' --no-pager 2>/dev/null | tail -20"
```
- Look for hardware errors, OOM kills, filesystem errors, segfaults.

**H. Security Snapshot**
```bash
ssh <target> "echo '=== RECENT LOGINS ==='; last -10 2>/dev/null; echo '=== FAILED LOGINS ==='; lastb 2>/dev/null | head -10; echo '=== SSH CONFIG ==='; grep -E '^(PermitRootLogin|PasswordAuthentication|Port)' /etc/ssh/sshd_config 2>/dev/null"
```
- Flag suspicious logins (unknown IPs). Flag weak SSH config (root login allowed, password auth on).

### Report Template

After all checks complete, produce a report in this exact format:

```markdown
# 🩺 Linux Server Health Report
**Server**: <hostname/IP>
**Time**: <timestamp>
**Mode**: Patrol

## 📊 Summary
- Overall Status: 🟢 Healthy / 🟡 Warnings / 🔴 Critical
- Total Checks: N | Passed: N | Warnings: N | Critical: N

## 🔴 Critical Findings
> List issues that need immediate attention. Each with: symptom, impact, fix command.

## 🟡 Warnings
> List non-urgent issues to address soon.

## 📋 Detailed Results
### CPU & Load
| Metric | Value | Status |
|--------|-------|--------|
| Load (1/5/15m) | ... | 🟢/🟡/🔴 |
| CPU Cores | ... | |
| Top Process | ... | |

### Memory
| Metric | Value | Status |
|--------|-------|--------|
| Total/Used/Avail | ... | 🟢/🟡/🔴 |
| Top Process | ... | |

### Disk
| Mount | Total | Used | Use% | Status |
|-------|-------|------|------|--------|
| / | ... | ... | ...% | 🟢/🟡/🔴 |

### Network · Services · Security
(Same pattern — adapt to findings)

## 🛠 Recommended Actions
1. **Priority 1**: `<action>` — `<reason>`
2. **Priority 2**: `<action>` — `<reason>`
```

## Mode 2: Troubleshoot (问题排查)

When the user describes a specific problem, DO NOT run all checks blindly. Follow this triage flow:

### Step 1: Categorize the Symptom

Map the user's description to one or more of these categories, then run ONLY the relevant targeted commands:

| Symptom | Likely Category | Targeted Commands |
|---------|----------------|-------------------|
| "server slow", "laggy", "high load" | CPU / Memory | `top -bn1 \| head -20`, `free -h`, `uptime` |
| "can't connect", "timeout", "network" | Network / Service | `ss -tlnp`, `systemctl is-active <service>`, `ip addr` |
| "disk full", "no space" | Disk | `df -h`, `du -sh /var/* \| sort -rh \| head -10`, `df -i` |
| "service X down", "crashed" | Service / Logs | `systemctl status <service>`, `journalctl -u <service> --no-pager -n 50` |
| "OOM", "killed", "out of memory" | Memory / OOM | `dmesg \| grep -i oom`, `free -h`, `ps aux --sort=-%mem \| head -10` |
| "can't SSH", "login failed" | Security / Auth | `lastb \| head -20`, `journalctl -u sshd --no-pager -n 30`, check `/etc/ssh/sshd_config` |
| "reboot loop", "crashed unexpectedly" | Hardware / Kernel | `dmesg --level=err \| tail -30`, `journalctl -p err --no-pager -n 50` |

### Step 2: Run Targeted Checks

Execute the commands for the matched category. If findings point to another category, cascade. For example, "service down" → check logs → find OOM → cascade to memory diagnostics.

### Step 3: Analyze and Explain

For each finding, explain in plain language:
- **What happened**: e.g., "MySQL was killed by the OOM killer at 14:32"
- **Why**: e.g., "The server has only 2GB RAM and 3 Java processes were competing for memory"
- **Fix**: Give the exact command to fix or mitigate

### Step 4: Output Fix-First Report

```markdown
# 🔧 Linux Server Troubleshooting Report
**Server**: <hostname/IP>
**Symptom**: <user's description>
**Root Cause**: <most likely cause>

## 🎯 Immediate Fix
\`\`\`bash
<exact command(s) to fix the problem>
\`\`\`

## 🔍 Analysis
> Diagnostic evidence chain. What commands found what.

## 🛡 Prevention
> Steps to prevent recurrence (monitoring, config changes, resource upgrades).
```

## Key Interpretation Rules

When analyzing command output, apply these heuristics:

- **Load > CPU cores**: System is overloaded. Identify top CPU process. If it's normal (e.g., a build job), it's transient. If it's persistent, investigate.
- **Available memory < 20% and swap > 50%**: Memory pressure. Check for memory leaks (growing RSS over time).
- **Disk > 90%**: Immediate action needed. Check `/var/log` for oversized logs, `/tmp` for temp files, Docker images (`docker system df`), old kernels.
- **Failed systemd units**: Always check `journalctl -u <unit>` for the last 50 lines before the failure.
- **Many SSH brute force attempts** (10+ in `lastb`): Recommend `fail2ban` or changing SSH port.
- **dmesg shows hardware errors** (MCE, PCIe, disk I/O errors): Recommend physical hardware check / cloud instance migration.

## Important Notes

- **Never modify** anything on the server without user approval. This skill is read-only diagnostics.
- **Respect data privacy**: Don't log or store command output containing user data, IPs, or credentials.
- If SSH fails with "Permission denied", suggest checking `ssh-copy-id` or key permissions — don't spend more than one message on SSH setup.
- For K3s/K8s servers, also check: `kubectl get nodes`, `kubectl get pods --all-namespaces`, `kubectl top nodes` if metrics-server is installed.

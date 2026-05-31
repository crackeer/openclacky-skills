---
name: linux-server-info
description: 'Collect comprehensive Linux server system information via SSH and generate a Markdown report. Covers CPU, GPU, memory, device serial number, OS details, and system architecture. Use when the user asks about server specs, hardware info, system inventory, server audit, machine details, or wants to collect system information from a remote Linux server.'
disable-model-invocation: false
user-invocable: true
---

# Linux Server Info Collector

Collect comprehensive system information from a remote Linux server via SSH and generate a well-structured Markdown report.

## When to Use

- User asks to "check server specs", "collect system info", "audit hardware"
- User wants to know CPU model, memory, GPU, OS details of a remote server
- User needs a hardware inventory report for one or more servers
- User mentions any of: server info, system information, hardware specs, machine details, server audit, 服务器信息, 系统信息

## Prerequisites

- SSH access to the target server (password, key file, or ssh-agent)
- The target server is a Linux machine (any distribution)
- `dmidecode` may require `sudo` — the script handles this gracefully

## Workflow

### Step 1: Gather Connection Details

Ask the user for:
- **Host** (IP or hostname) — required
- **User** (SSH username) — defaults to `root`
- **Port** — defaults to `22`
- **Identity file** (path to SSH private key) — optional, uses ssh-agent if omitted

If the user provides incomplete info, ask only for what's missing.

### Step 2: Run the Collection Script

Use the bundled script to collect all information in one SSH session:

```bash
ruby "SKILL_DIR/scripts/collect.rb" \
  --host <host> \
  --user <user> \
  [--port <port>] \
  [--identity <path>] \
  [--output <output.md>]
```

The script will:
1. Run all collection commands over a single SSH connection
2. Parse and format the output into structured Markdown
3. Save the report to the specified output file (default: `server-info-<host>.md`)

Default output path is in the current working directory.

### Step 3: Present the Report

Read the generated Markdown file and present a summary to the user. Highlight:
- Any anomalies (high memory usage, disk near full, unexpected hardware)
- Missing information (e.g., no GPU found, dmidecode requires sudo)
- Key specs: CPU model & cores, total RAM, GPU info, OS version

Append the file link: `[server-info-<host>.md](file://<absolute-path>)`

## What's Collected

| Category | Commands Used | Fallback |
|----------|--------------|----------|
| **CPU** | `lscpu`, `/proc/cpuinfo` | `nproc`, `arch` |
| **Device SN** | `dmidecode -s system-serial-number`, cloud metadata | `hostnamectl` |
| **GPU** | `lspci | grep -iE 'vga|3d|display'`, `nvidia-smi` | `lshw -c display` |
| **Memory** | `free -h`, `/proc/meminfo`, `dmidecode -t memory` | `vmstat -s` |
| **OS** | `cat /etc/os-release`, `uname -a`, `hostnamectl` | `lsb_release -a` |
| **Architecture** | `uname -m`, `lscpu | grep Arch`, `getconf LONG_BIT` | `arch` |

## Dealing with Permissions

- `dmidecode` often requires root. The script runs it with `sudo` and falls back gracefully if denied.
- For cloud instances, the script tries cloud metadata endpoints (AWS IMDS, GCP, Azure) to fetch instance info.
- If a command fails, the section is marked with "⚠️ Not available (permission denied)" rather than blocking the entire report.

## Multi-Server Collection

If the user wants to collect info from multiple servers, run the script once per server with different `--host` and `--output` arguments. Process them sequentially — SSH connections are not parallelized.

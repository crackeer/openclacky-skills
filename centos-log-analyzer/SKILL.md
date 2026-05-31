---
name: centos-log-analyzer
description: 'Analyze CentOS 7.9 server logs including system logs (/var/log/messages), dmesg, and sa (sysstat) logs. Use this skill when the user wants to analyze server logs, troubleshoot system issues, review performance data, or investigate hardware/software problems from CentOS servers.'
disable-model-invocation: false
user-invocable: true
---

# CentOS Log Analyzer

An MCP server for analyzing CentOS 7.9 server logs. Supports three log types:
- **System logs** (/var/log/messages) - service events, authentication, errors
- **dmesg logs** - hardware errors, kernel messages, driver issues
- **sa logs** (sysstat) - CPU, memory, disk I/O, network performance

## Usage

When user provides log files, use the bundled Ruby scripts to parse and analyze them.

### Supported File Types

1. **System logs**: `/var/log/messages`, `/var/log/syslog`, or any syslog-format file
2. **dmesg logs**: Output from `dmesg` or `/var/log/dmesg`
3. **sa logs**: Binary sa files from sysstat (`/var/log/sa/sa*`) or text output from `sar`

### Analysis Workflow

#### Step 1: Identify Log Type

Ask user which logs they have, or detect from filename/content:
- Files with timestamps like `May 30 10:00:00` → system log
- Lines starting with `[timestamp]` or containing kernel messages → dmesg
- Files with `%idle`, `%user`, `tps` columns → sa/sar output

#### Step 2: Run Analysis Scripts

**System log analysis:**
```bash
ruby "SKILL_DIR/scripts/analyze_syslog.rb" /path/to/messages
```

**dmesg analysis:**
```bash
ruby "SKILL_DIR/scripts/analyze_dmesg.rb" /path/to/dmesg.log
```

**sa/sar analysis:**
```bash
ruby "SKILL_DIR/scripts/analyze_sa.rb" /path/to/sar_output.txt
```

#### Step 3: Generate Report

After running scripts, compile findings into a structured report:

```markdown
# CentOS Server Log Analysis Report

## Executive Summary
- Total errors found: X
- Critical issues: X
- Time range analyzed: YYYY-MM-DD to YYYY-MM-DD

## System Log Analysis
### Key Findings
- [List main issues]

### Service Events
- [Service starts/stops/failures]

### Authentication Issues
- [Failed logins, permission errors]

## dmesg Analysis
### Hardware Issues
- [CPU, memory, disk errors]

### Kernel Warnings
- [Driver issues, OOM events]

## Performance Analysis (sa/sar)
### CPU Usage
- Average: X%
- Peak: X% at [time]

### Memory Usage
- Average: X%
- Swap usage: X%

### Disk I/O
- Read: X KB/s
- Write: X KB/s

## Recommendations
1. [Actionable suggestion]
2. [Actionable suggestion]
```

## Script Details

### analyze_syslog.rb
Parses syslog/messages format:
- Extracts error/warning lines
- Identifies service start/stop events
- Detects authentication failures
- Groups by time periods
- Outputs JSON summary

### analyze_dmesg.rb
Parses dmesg output:
- Detects hardware errors (CPU, memory, disk, NIC)
- Identifies OOM killer events
- Finds driver loading failures
- Extracts kernel panic/oops
- Outputs JSON summary

### analyze_sa.rb
Parses sar text output:
- CPU usage statistics (user, system, idle, iowait)
- Memory and swap usage
- Disk I/O throughput
- Network interface statistics
- Load average trends
- Outputs JSON summary

## Example Usage

**User**: "I have /var/log/messages from my CentOS server, can you analyze it?"

**Response**:
1. Run: `ruby SKILL_DIR/scripts/analyze_syslog.rb /var/log/messages`
2. Read the JSON output
3. Generate markdown report with findings
4. Provide recommendations

## Notes

- Scripts output JSON to stdout for easy parsing
- Large log files are processed line-by-line (memory efficient)
- Time ranges are automatically detected
- All scripts handle CentOS 7.9 log format specifically

# CentOS Log Analyzer

An MCP server for analyzing CentOS 7.9 server logs. Supports three log types:
- **System logs** (/var/log/messages) - service events, authentication, errors
- **dmesg logs** - hardware errors, kernel messages, driver issues
- **sa logs** (sysstat) - CPU, memory, disk I/O, network performance

## Installation

This skill is installed at `~/.clacky/skills/centos-log-analyzer/`

## Usage

### System Log Analysis

Analyze syslog/messages format logs:

```bash
ruby ~/.clacky/skills/centos-log-analyzer/scripts/analyze_syslog.rb /var/log/messages
```

**Features:**
- Extracts error and warning lines
- Identifies service start/stop/restart events
- Detects authentication failures
- Categorizes errors by type (disk, memory, network, auth, services)
- Time range detection

### dmesg Analysis

Analyze kernel ring buffer logs:

```bash
ruby ~/.clacky/skills/centos-log-analyzer/scripts/analyze_dmesg.rb /path/to/dmesg.log
```

**Features:**
- Hardware error detection (CPU, memory, disk, NIC)
- OOM killer event detection
- Driver loading failures
- Kernel panic/oops detection
- Critical issue severity classification

### sa/sar Analysis

Analyze sysstat performance data:

```bash
ruby ~/.clacky/skills/centos-log-analyzer/scripts/analyze_sa.rb /path/to/sar_output.txt
```

**Features:**
- CPU usage statistics (user, system, iowait, idle)
- Memory and swap usage
- Disk I/O throughput
- Network interface statistics
- System load trends
- Performance bottleneck detection

## Output Format

All scripts output JSON to stdout for easy parsing. Example:

```json
{
  "file": "/var/log/messages",
  "summary": {
    "total_lines": 1234,
    "error_count": 15,
    "warning_count": 8
  },
  "errors": [...],
  "warnings": [...],
  "recommendations": [...]
}
```

## Integration with Clacky

This skill is designed to be used with the Clacky agent. When analyzing logs:

1. User provides log files
2. Agent runs appropriate script
3. Agent reads JSON output
4. Agent generates markdown report with findings and recommendations

## Supported Log Formats

### System Logs
- CentOS 7.9 `/var/log/messages` format
- Standard syslog format: `MMM DD HH:MM:SS hostname service[pid]: message`

### dmesg Logs
- Kernel timestamp format: `[12345.678901] message`
- Standard dmesg output

### sa/sar Logs
- Text output from `sar` command
- Standard sysstat output format

## Performance Issue Detection

The scripts automatically detect:

- **CPU**: High iowait (>20%), low idle (<10%)
- **Memory**: High usage (>90%), high swap (>50%)
- **Load**: High system load (>10)
- **Disk**: I/O errors, high throughput
- **Network**: Interface errors

## Recommendations

Each script provides actionable recommendations based on detected issues:

- Disk health checks
- Memory optimization
- CPU scaling
- Network troubleshooting
- Hardware diagnostics

## License

MIT

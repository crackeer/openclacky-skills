# openclacky-skills

Community skills for [Clacky](https://github.com/crackeer/openclacky) AI assistant.

## Available Skills

### linux-server-info
Collect comprehensive system information from a remote Linux server via SSH and generate a structured Markdown report. Covers CPU, memory, GPU, OS, device serial number, and server architecture.

```bash
ruby linux-server-info/scripts/collect.rb --host <host> --user <user> [--port <port>]
```

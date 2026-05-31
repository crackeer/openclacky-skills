#!/usr/bin/env ruby
# linux-server-info/scripts/collect.rb
# Usage: ruby collect.rb --host <host> --user <user> [--port <port>] [--identity <path>] [--output <file>]

require 'optparse'
require 'open3'
require 'time'

# --- Parse arguments ---
options = { port: 22, output: nil }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby collect.rb --host HOST --user USER [options]"
  opts.on("--host HOST", "SSH host (required)") { |v| options[:host] = v }
  opts.on("--user USER", "SSH user (required)") { |v| options[:user] = v }
  opts.on("--port PORT", Integer, "SSH port (default: 22)") { |v| options[:port] = v }
  opts.on("--identity PATH", "SSH identity file") { |v| options[:identity] = v }
  opts.on("--output PATH", "Output Markdown file") { |v| options[:output] = v }
end.parse!

unless options[:host] && options[:user]
  warn "ERROR: --host and --user are required."
  exit 1
end

host     = options[:host]
user     = options[:user]
port     = options[:port]
identity = options[:identity]
output_file = options[:output] || "server-info-#{host}.md"

# --- Build SSH command prefix ---
ssh_opts = "-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -p #{port}"
ssh_opts += " -i #{identity}" if identity
remote = "#{user}@#{host}"

# --- Helper: run a command over SSH, return stdout ---
def ssh_exec(ssh_prefix, remote, cmd)
  full_cmd = "ssh #{ssh_prefix} #{remote} '#{cmd}' 2>/dev/null"
  stdout, _stderr, status = Open3.capture3(full_cmd)
  status.success? ? stdout.strip : nil
end

# --- Helper: try command with sudo fallback ---
def ssh_exec_sudo(ssh_prefix, remote, cmd)
  result = ssh_exec(ssh_prefix, remote, cmd)
  return result if result && !result.empty?
  ssh_exec(ssh_prefix, remote, "sudo #{cmd}")
end

puts "🔍 Connecting to #{user}@#{host}:#{port}..."
puts

# ====================== COLLECT DATA ======================

# --- OS Info ---
os_release    = ssh_exec(ssh_opts, remote, "cat /etc/os-release 2>/dev/null")
hostnamectl   = ssh_exec(ssh_opts, remote, "hostnamectl 2>/dev/null")
uname_all     = ssh_exec(ssh_opts, remote, "uname -a")
lsb_release   = ssh_exec(ssh_opts, remote, "lsb_release -a 2>/dev/null")

# --- CPU Info ---
lscpu_output  = ssh_exec(ssh_opts, remote, "LANG=C lscpu 2>/dev/null")
cpuinfo       = ssh_exec(ssh_opts, remote, "cat /proc/cpuinfo 2>/dev/null")
nproc_output  = ssh_exec(ssh_opts, remote, "nproc")

# --- Device SN ---
dmidecode_sn  = ssh_exec_sudo(ssh_opts, remote, "dmidecode -s system-serial-number 2>/dev/null")
dmidecode_pn  = ssh_exec_sudo(ssh_opts, remote, "dmidecode -s system-product-name 2>/dev/null")
dmidecode_man = ssh_exec_sudo(ssh_opts, remote, "dmidecode -s system-manufacturer 2>/dev/null")
dmidecode_uuid = ssh_exec_sudo(ssh_opts, remote, "dmidecode -s system-uuid 2>/dev/null")

# Cloud metadata
aws_imds = ssh_exec(ssh_opts, remote, "curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null")
gcp_meta = ssh_exec(ssh_opts, remote, "curl -s --connect-timeout 2 -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/id 2>/dev/null")
azure_meta = ssh_exec(ssh_opts, remote, "curl -s --connect-timeout 2 -H 'Metadata:true' 'http://169.254.169.254/metadata/instance/compute/name?api-version=2021-02-01&format=text' 2>/dev/null")

# --- GPU Info ---
lspci_gpu     = ssh_exec(ssh_opts, remote, "lspci | grep -iE 'vga|3d|display' 2>/dev/null")
nvidia_smi    = ssh_exec(ssh_opts, remote, "nvidia-smi --query-gpu=index,name,driver_version,memory.total,memory.used,memory.free,temperature.gpu,utilization.gpu --format=csv,noheader 2>/dev/null")
lshw_gpu      = ssh_exec_sudo(ssh_opts, remote, "lshw -c display -short 2>/dev/null")

# --- Memory Info ---
free_h        = ssh_exec(ssh_opts, remote, "free -h 2>/dev/null")
meminfo       = ssh_exec(ssh_opts, remote, "cat /proc/meminfo 2>/dev/null")
dmidecode_mem = ssh_exec_sudo(ssh_opts, remote, "dmidecode -t memory 2>/dev/null")
vmstat_s      = ssh_exec(ssh_opts, remote, "vmstat -s 2>/dev/null")

# --- Architecture ---
uname_m       = ssh_exec(ssh_opts, remote, "uname -m")
arch_output   = ssh_exec(ssh_opts, remote, "arch 2>/dev/null")
long_bit      = ssh_exec(ssh_opts, remote, "getconf LONG_BIT 2>/dev/null")

# --- Disk (bonus) ---
df_h          = ssh_exec(ssh_opts, remote, "df -h 2>/dev/null")
lsblk         = ssh_exec(ssh_opts, remote, "lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null")

# --- Network (bonus) ---
ip_addr       = ssh_exec(ssh_opts, remote, "ip addr show 2>/dev/null || ip a 2>/dev/null")

# --- Uptime & Load ---
uptime_out    = ssh_exec(ssh_opts, remote, "uptime 2>/dev/null")
load_avg      = ssh_exec(ssh_opts, remote, "cat /proc/loadavg 2>/dev/null")

# ====================== PARSE & GENERATE REPORT ======================

def parse_os_release(text)
  return {} unless text
  text.lines.each_with_object({}) do |line, h|
    k, v = line.strip.split('=', 2)
    next unless k && v
    h[k] = v.gsub(/^"|"$/, '')
  end
end

def parse_lscpu(text)
  return {} unless text
  text.lines.each_with_object({}) do |line, h|
    k, v = line.strip.split(':', 2)
    next unless k && v
    h[k.strip] = v.strip
  end
end

def parse_meminfo(text)
  return {} unless text
  text.lines.each_with_object({}) do |line, h|
    parts = line.strip.split(':')
    next unless parts.length >= 2
    h[parts[0].strip] = parts[1..].join(':').strip
  end
end

os_data   = parse_os_release(os_release)
cpu_data  = parse_lscpu(lscpu_output)
mem_data  = parse_meminfo(meminfo)

report = []
report << "# 🖥️ Server System Information Report"
report << ""
report << "**Host:** `#{host}` | **Collected at:** #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')} | **User:** `#{user}`"
report << ""

# --- 1. Operating System ---
report << "## 1. Operating System"
report << ""
if os_release && !os_release.empty?
  report << "| Field | Value |"
  report << "|-------|-------|"
  report << "| **Name** | #{os_data['NAME'] || 'N/A'} |"
  report << "| **Version** | #{os_data['VERSION'] || 'N/A'} |"
  report << "| **ID** | #{os_data['ID'] || 'N/A'} |"
  report << "| **Version ID** | #{os_data['VERSION_ID'] || 'N/A'} |"
  report << "| **Pretty Name** | #{os_data['PRETTY_NAME'] || 'N/A'} |"
  report << "| **Kernel** | #{uname_all ? uname_all.split[2] : 'N/A'} |"
else
  report << "| Field | Value |"
  report << "|-------|-------|"
  report << "| **Kernel** | #{uname_all || 'N/A'} |"
end
report << ""
if uname_all
  report << "```"
  report << uname_all
  report << "```"
  report << ""
end

# --- 2. CPU ---
report << "## 2. CPU"
report << ""
if cpu_data.any?
  report << "| Field | Value |"
  report << "|-------|-------|"
  report << "| **Model** | #{cpu_data['Model name'] || 'N/A'} |"
  report << "| **Architecture** | #{cpu_data['Architecture'] || 'N/A'} |"
  report << "| **CPU(s)** | #{cpu_data['CPU(s)'] || 'N/A'} |"
  report << "| **Thread(s) per core** | #{cpu_data['Thread(s) per core'] || 'N/A'} |"
  report << "| **Core(s) per socket** | #{cpu_data['Core(s) per socket'] || 'N/A'} |"
  report << "| **Socket(s)** | #{cpu_data['Socket(s)'] || 'N/A'} |"
  report << "| **CPU MHz** | #{cpu_data['CPU MHz'] || cpu_data['CPU max MHz'] || 'N/A'} |"
  report << "| **L1d cache** | #{cpu_data['L1d cache'] || 'N/A'} |"
  report << "| **L1i cache** | #{cpu_data['L1i cache'] || 'N/A'} |"
  report << "| **L2 cache** | #{cpu_data['L2 cache'] || 'N/A'} |"
  report << "| **L3 cache** | #{cpu_data['L3 cache'] || 'N/A'} |"
  report << "| **Flags** | #{cpu_data['Flags'] ? cpu_data['Flags'][0..120] + '...' : 'N/A'} |"
  report << ""
end
if nproc_output
  report << "**Logical processors (nproc):** #{nproc_output}"
  report << ""
end

# --- 3. Device SN ---
report << "## 3. Device Serial Number & Identity"
report << ""
report << "| Field | Value |"
report << "|-------|-------|"
report << "| **Manufacturer** | #{dmidecode_man || '⚠️ Not available'} |"
report << "| **Product Name** | #{dmidecode_pn || '⚠️ Not available'} |"
report << "| **Serial Number** | #{dmidecode_sn || '⚠️ Not available'} |"
report << "| **System UUID** | #{dmidecode_uuid || '⚠️ Not available'} |"

if aws_imds
  report << "| **AWS Instance ID** | #{aws_imds} |"
end
if gcp_meta
  report << "| **GCP Instance ID** | #{gcp_meta} |"
end
if azure_meta
  report << "| **Azure Instance Name** | #{azure_meta} |"
end
report << ""

# --- 4. GPU ---
report << "## 4. GPU"
report << ""
if lspci_gpu && !lspci_gpu.empty?
  report << "### PCI Devices"
  report << ""
  report << "```"
  report << lspci_gpu
  report << "```"
  report << ""
end

if nvidia_smi && !nvidia_smi.empty?
  report << "### NVIDIA GPU Details"
  report << ""
  report << "| Index | Name | Driver | Total Mem | Used Mem | Free Mem | Temp | GPU Util |"
  report << "|-------|------|--------|-----------|----------|----------|------|----------|"
  nvidia_smi.lines.each do |line|
    cols = line.strip.split(', ')
    report << "| #{cols.join(' | ')} |"
  end
  report << ""
elsif lspci_gpu && !lspci_gpu.empty?
  report << "⚠️ `nvidia-smi` not available (no NVIDIA driver or no GPU)."
  report << ""
else
  report << "⚠️ No GPU detected."
  report << ""
end

# --- 5. Memory ---
report << "## 5. Memory"
report << ""
if free_h && !free_h.empty?
  report << "### Overview"
  report << ""
  report << "```"
  report << free_h
  report << "```"
  report << ""
end

if mem_data.any?
  report << "### Details"
  report << ""
  report << "| Field | Value |"
  report << "|-------|-------|"
  %w[MemTotal MemFree MemAvailable Buffers Cached SwapTotal SwapFree].each do |key|
    report << "| **#{key}** | #{mem_data[key] || 'N/A'} |"
  end
  report << ""
end

if dmidecode_mem && !dmidecode_mem.empty?
  report << "### Physical Memory Modules (DMI)"
  report << ""
  report << "```"
  # Extract size, type, speed, manufacturer lines
  relevant_lines = dmidecode_mem.lines.select { |l| l.match?(/Size|Type:|Speed:|Manufacturer:|Serial Number:|Part Number:|Locator:/) }
  report << relevant_lines.join
  report << "```"
  report << ""
end

# --- 6. Architecture ---
report << "## 6. System Architecture"
report << ""
report << "| Field | Value |"
report << "|-------|-------|"
report << "| **Kernel Arch (uname -m)** | #{uname_m || 'N/A'} |"
report << "| **Arch (arch)** | #{arch_output || 'N/A'} |"
report << "| **CPU Arch** | #{cpu_data['Architecture'] || 'N/A'} |"
report << "| **CPU Mode(s)** | #{cpu_data['CPU op-mode(s)'] || 'N/A'} |"
report << "| **Byte Order** | #{cpu_data['Byte Order'] || 'N/A'} |"
report << "| **Address sizes** | #{cpu_data['Address sizes'] || 'N/A'} |"
report << "| **Word Size** | #{long_bit ? "#{long_bit}-bit" : 'N/A'} |"
report << ""

# --- 7. Disk (bonus) ---
report << "## 7. Disk Usage"
report << ""
if df_h && !df_h.empty?
  report << "```"
  report << df_h
  report << "```"
  report << ""
end
if lsblk && !lsblk.empty?
  report << "### Block Devices"
  report << ""
  report << "```"
  report << lsblk
  report << "```"
  report << ""
end

# --- 8. Network (bonus) ---
report << "## 8. Network Interfaces"
report << ""
if ip_addr && !ip_addr.empty?
  report << "```"
  report << ip_addr
  report << "```"
  report << ""
end

# --- 9. Uptime ---
report << "## 9. Uptime & Load"
report << ""
if uptime_out
  report << "```"
  report << uptime_out
  report << "```"
  report << ""
end

# --- Write report ---
File.write(output_file, report.join("\n"))
puts "✅ Report saved to: #{output_file}"
puts "   #{File.expand_path(output_file)}"

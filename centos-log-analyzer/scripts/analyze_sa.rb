#!/usr/bin/env ruby
# CentOS sa/sar Performance Data Analyzer
# Usage: ruby analyze_sa.rb /path/to/sar_output.txt

require 'json'

class SaAnalyzer
  def initialize(file_path)
    @file_path = file_path
    @cpu_data = []
    @memory_data = []
    @disk_data = []
    @network_data = []
    @load_data = []
    @current_section = nil
  end

  def analyze
    return nil unless File.exist?(@file_path)

    line_num = 0
    File.foreach(@file_path) do |line|
      line_num += 1
      parse_line(line.strip, line_num)
    end

    generate_report
  end

  private

  def parse_line(line, line_num)
    # Skip empty lines and averages
    return if line.empty? || line.match(/^Average:|^$/)
    
    # Skip header lines
    return if line.match(/CPU\s+%user|%memfree|tps\s+rtps|IFACE\s+rxpck|runq-sz/)

    # Detect section by content
    if line.match(/^\d{1,2}:\d{2}:\d{2}\s+[AP]M\s+all\s+/)
      parse_cpu_line(line)
    elsif line.match(/^\d{1,2}:\d{2}:\d{2}\s+[AP]M\s+\d+\s+\d+\s+\d+\s+\d+/)
      parse_memory_line(line)
    elsif line.match(/^\d{1,2}:\d{2}:\d{2}\s+[AP]M\s+eth\d+/)
      parse_network_line(line)
    elsif line.match(/^\d{1,2}:\d{2}:\d{2}\s+[AP]M\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+/)
      parse_disk_line(line)
    elsif line.match(/^\d{1,2}:\d{2}:\d{2}\s+[AP]M\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+/)
      parse_load_line(line)
    end
  end

  def parse_cpu_line(line)
    # Format: "12:10:01 AM     all     25.34      0.00      8.12     45.67      0.00     20.87"
    parts = line.split(/\s+/)
    return unless parts.length >= 8
    
    time = "#{parts[0]} #{parts[1]}"
    @cpu_data << {
      time: time,
      user: parts[3].to_f,
      nice: parts[4].to_f,
      system: parts[5].to_f,
      iowait: parts[6].to_f,
      steal: parts[7].to_f,
      idle: parts[8].to_f
    }
  end

  def parse_memory_line(line)
    # Format: "12:10:01 AM    234567   456789    765432     76.54    123456    345678    1234567     234532     15.94     123456"
    parts = line.split(/\s+/)
    return unless parts.length >= 11
    
    time = "#{parts[0]} #{parts[1]}"
    @memory_data << {
      time: time,
      kbmemfree: parts[2].to_i,
      kbavail: parts[3].to_i,
      kbmemused: parts[4].to_i,
      pct_memused: parts[5].to_f,
      kbbuffers: parts[6].to_i,
      kbcached: parts[7].to_i,
      kbswpfree: parts[8].to_i,
      kbswpused: parts[9].to_f,
      pct_swpused: parts[10].to_f
    }
  end

  def parse_disk_line(line)
    # Format: "12:10:01 AM    234.56  123.45  111.11    0.00  12345.67  23456.78"
    parts = line.split(/\s+/)
    return unless parts.length >= 8
    
    time = "#{parts[0]} #{parts[1]}"
    @disk_data << {
      time: time,
      tps: parts[2].to_f,
      rtps: parts[3].to_f,
      wtps: parts[4].to_f,
      dtps: parts[5].to_f,
      bread_s: parts[6].to_f,
      bwrtn_s: parts[7].to_f
    }
  end

  def parse_network_line(line)
    # Format: "12:10:01 AM      eth0   1234.56   1123.45    567.89    456.78"
    parts = line.split(/\s+/)
    return unless parts.length >= 7
    
    time = "#{parts[0]} #{parts[1]}"
    @network_data << {
      time: time,
      iface: parts[2],
      rxpck_s: parts[3].to_f,
      txpck_s: parts[4].to_f,
      rxkB_s: parts[5].to_f,
      txkB_s: parts[6].to_f
    }
  end

  def parse_load_line(line)
    # Format: "12:10:01 AM      12.00    345.00     12.34     10.23      8.90"
    parts = line.split(/\s+/)
    return unless parts.length >= 7
    
    time = "#{parts[0]} #{parts[1]}"
    @load_data << {
      time: time,
      runq_sz: parts[2].to_f,
      plist_sz: parts[3].to_f,
      ldavg_1: parts[4].to_f,
      ldavg_5: parts[5].to_f,
      ldavg_15: parts[6].to_f
    }
  end

  def generate_report
    {
      file: @file_path,
      cpu: cpu_summary,
      memory: memory_summary,
      disk: disk_summary,
      network: network_summary,
      load: load_summary,
      performance_issues: detect_issues,
      recommendations: generate_recommendations
    }
  end

  def cpu_summary
    return {} if @cpu_data.empty?
    
    {
      data_points: @cpu_data.length,
      avg_user: avg(@cpu_data.map { |d| d[:user] }),
      avg_system: avg(@cpu_data.map { |d| d[:system] }),
      avg_iowait: avg(@cpu_data.map { |d| d[:iowait] }),
      avg_idle: avg(@cpu_data.map { |d| d[:idle] }),
      max_user: @cpu_data.map { |d| d[:user] }.max,
      max_system: @cpu_data.map { |d| d[:system] }.max,
      max_iowait: @cpu_data.map { |d| d[:iowait] }.max
    }
  end

  def memory_summary
    return {} if @memory_data.empty?
    
    {
      data_points: @memory_data.length,
      avg_pct_used: avg(@memory_data.map { |d| d[:pct_memused] }),
      max_pct_used: @memory_data.map { |d| d[:pct_memused] }.max,
      avg_kbfree: avg(@memory_data.map { |d| d[:kbmemfree] }),
      min_kbfree: @memory_data.map { |d| d[:kbmemfree] }.min,
      avg_swpused: avg(@memory_data.map { |d| d[:pct_swpused] })
    }
  end

  def disk_summary
    return {} if @disk_data.empty?
    
    {
      data_points: @disk_data.length,
      avg_tps: avg(@disk_data.map { |d| d[:tps] }),
      avg_read_kbs: avg(@disk_data.map { |d| d[:bread_s] }) / 1024,
      avg_write_kbs: avg(@disk_data.map { |d| d[:bwrtn_s] }) / 1024,
      max_tps: @disk_data.map { |d| d[:tps] }.max
    }
  end

  def network_summary
    return {} if @network_data.empty?
    
    interfaces = @network_data.map { |d| d[:iface] }.uniq
    result = {}
    interfaces.each do |iface|
      iface_data = @network_data.select { |d| d[:iface] == iface }
      result[iface] = {
        avg_rx_kbs: avg(iface_data.map { |d| d[:rxkB_s] }),
        avg_tx_kbs: avg(iface_data.map { |d| d[:txkB_s] }),
        max_rx_kbs: iface_data.map { |d| d[:rxkB_s] }.max,
        max_tx_kbs: iface_data.map { |d| d[:txkB_s] }.max
      }
    end
    result
  end

  def load_summary
    return {} if @load_data.empty?
    
    {
      data_points: @load_data.length,
      avg_load_1: avg(@load_data.map { |d| d[:ldavg_1] }),
      avg_load_5: avg(@load_data.map { |d| d[:ldavg_5] }),
      avg_load_15: avg(@load_data.map { |d| d[:ldavg_15] }),
      max_load_1: @load_data.map { |d| d[:ldavg_1] }.max
    }
  end

  def detect_issues
    issues = []
    
    # CPU issues
    cpu = cpu_summary
    if cpu[:avg_iowait] && cpu[:avg_iowait] > 20
      issues << { severity: "high", category: "CPU", metric: "iowait", value: cpu[:avg_iowait], message: "High I/O wait indicates disk bottleneck" }
    end
    if cpu[:avg_idle] && cpu[:avg_idle] < 10
      issues << { severity: "high", category: "CPU", metric: "idle", value: cpu[:avg_idle], message: "CPU overloaded - very low idle time" }
    end

    # Memory issues
    mem = memory_summary
    if mem[:avg_pct_used] && mem[:avg_pct_used] > 90
      issues << { severity: "high", category: "Memory", metric: "usage", value: mem[:avg_pct_used], message: "Memory usage critically high" }
    end
    if mem[:avg_swpused] && mem[:avg_swpused] > 50
      issues << { severity: "medium", category: "Memory", metric: "swap", value: mem[:avg_swpused], message: "High swap usage detected" }
    end

    # Load issues
    load = load_summary
    if load[:max_load_1] && load[:max_load_1] > 10
      issues << { severity: "medium", category: "Load", metric: "load_1m", value: load[:max_load_1], message: "High system load detected" }
    end

    issues
  end

  def generate_recommendations
    recs = []
    issues = detect_issues
    
    issues.each do |issue|
      case issue[:category]
      when "CPU"
        if issue[:metric] == "iowait"
          recs << "Investigate disk I/O bottleneck - check disk health and RAID status"
          recs << "Consider SSD upgrade or storage optimization"
        else
          recs << "CPU overloaded - consider upgrading CPU or optimizing applications"
        end
      when "Memory"
        if issue[:metric] == "swap"
          recs << "High swap usage - add more RAM or reduce memory consumption"
        else
          recs << "Add more RAM or optimize memory usage"
          recs << "Check for memory leaks in applications"
        end
      when "Load"
        recs << "Identify processes causing high load with 'top' or 'htop'"
      end
    end
    
    recs << "Review full sar report for detailed time-based analysis" if recs.empty?
    recs
  end

  def avg(arr)
    return 0 if arr.empty?
    arr.sum.to_f / arr.length
  end
end

# Main
if ARGV.empty?
  puts '{"error": "Usage: ruby analyze_sa.rb /path/to/sar_output.txt"}'
  exit 1
end

analyzer = SaAnalyzer.new(ARGV[0])
result = analyzer.analyze

if result
  puts JSON.pretty_generate(result)
else
  puts '{"error": "File not found or empty"}'
  exit 1
end

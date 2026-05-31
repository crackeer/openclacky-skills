#!/usr/bin/env ruby
# CentOS dmesg Log Analyzer
# Usage: ruby analyze_dmesg.rb /path/to/dmesg.log

require 'json'

class DmesgAnalyzer
  def initialize(file_path)
    @file_path = file_path
    @hardware_errors = []
    @kernel_warnings = []
    @oom_events = []
    @driver_issues = []
    @disk_errors = []
    @memory_errors = []
    @network_errors = []
    @timestamps = []
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
    # Parse kernel timestamp: [12345.678901]
    timestamp_match = line.match(/\[(\d+\.\d+)\]/)
    if timestamp_match
      @timestamps << timestamp_match[1].to_f
    end

    # Hardware errors
    if line.match(/hardware error|mce|machine check|ghes|einj/i)
      @hardware_errors << { line: line_num, message: line }
    end

    # OOM killer events
    if line.match(/oom|out of memory|killed process/i)
      @oom_events << { line: line_num, message: line }
    end

    # Disk errors
    if line.match(/blk_update_request|I\/O error|ata\d+|scsi|disk|blk_/i)
      @disk_errors << { line: line_num, message: line }
    end

    # Memory errors
    if line.match(/memory failure|edac|mce.*memory|ram/i)
      @memory_errors << { line: line_num, message: line }
    end

    # Network errors
    if line.match(/eth\d+|nic|link is down|carrier|network|bond/i)
      @network_errors << { line: line_num, message: line }
    end

    # Driver issues
    if line.match(/driver|firmware|module.*fail|modprobe/i)
      @driver_issues << { line: line_num, message: line }
    end

    # Kernel warnings
    if line.match(/warn|warning|call trace|bug:|rip:|oops|panic/i)
      @kernel_warnings << { line: line_num, message: line }
    end
  end

  def generate_report
    {
      file: @file_path,
      summary: {
        total_messages: @timestamps.length,
        time_range: {
          boot: @timestamps.min,
          latest: @timestamps.max
        },
        hardware_errors: @hardware_errors.length,
        oom_events: @oom_events.length,
        disk_errors: @disk_errors.length,
        memory_errors: @memory_errors.length,
        network_errors: @network_errors.length,
        driver_issues: @driver_issues.length,
        kernel_warnings: @kernel_warnings.length
      },
      critical_issues: build_critical_issues,
      hardware_errors: @hardware_errors.first(20),
      oom_events: @oom_events.first(20),
      disk_errors: @disk_errors.first(20),
      memory_errors: @memory_errors.first(20),
      network_errors: @network_errors.first(20),
      driver_issues: @driver_issues.first(20),
      kernel_warnings: @kernel_warnings.first(20),
      recommendations: generate_recommendations
    }
  end

  def build_critical_issues
    issues = []
    issues << { severity: "critical", category: "OOM", count: @oom_events.length, message: "Out of memory killer events detected" } if @oom_events.length > 0
    issues << { severity: "critical", category: "Hardware", count: @hardware_errors.length, message: "Hardware errors detected" } if @hardware_errors.length > 0
    issues << { severity: "high", category: "Disk", count: @disk_errors.length, message: "Disk I/O errors detected" } if @disk_errors.length > 0
    issues << { severity: "high", category: "Memory", count: @memory_errors.length, message: "Memory errors detected" } if @memory_errors.length > 0
    issues << { severity: "medium", category: "Network", count: @network_errors.length, message: "Network errors detected" } if @network_errors.length > 0
    issues << { severity: "medium", category: "Driver", count: @driver_issues.length, message: "Driver issues detected" } if @driver_issues.length > 0
    issues
  end

  def generate_recommendations
    recs = []
    
    if @oom_events.length > 0
      recs << "CRITICAL: OOM killer active - increase RAM or reduce memory usage"
      recs << "Check application memory limits and swap configuration"
    end
    
    if @disk_errors.length > 0
      recs << "HIGH: Run disk health check (smartctl -a /dev/sdX)"
      recs << "Consider replacing disk if errors persist"
    end
    
    if @memory_errors.length > 0
      recs << "HIGH: Run memory test (memtest86+)"
      recs << "Check DIMM seating and replace faulty modules"
    end
    
    if @hardware_errors.length > 0
      recs << "CRITICAL: Hardware errors detected - check server hardware"
      recs << "Review IPMI/iDRAC logs for hardware details"
    end
    
    if @network_errors.length > 0
      recs << "Check network cables and switch connections"
      recs << "Verify NIC driver version and firmware"
    end
    
    recs
  end
end

# Main
if ARGV.empty?
  puts '{"error": "Usage: ruby analyze_dmesg.rb /path/to/dmesg.log"}'
  exit 1
end

analyzer = DmesgAnalyzer.new(ARGV[0])
result = analyzer.analyze

if result
  puts JSON.pretty_generate(result)
else
  puts '{"error": "File not found or empty"}'
  exit 1
end

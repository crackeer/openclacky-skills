#!/usr/bin/env ruby
# CentOS System Log Analyzer
# Usage: ruby analyze_syslog.rb /path/to/messages

require 'json'
require 'time'

class SyslogAnalyzer
  attr_reader :errors, :warnings, :services, :auth_issues, :time_range

  def initialize(file_path)
    @file_path = file_path
    @errors = []
    @warnings = []
    @services = []
    @auth_issues = []
    @time_range = { start: nil, end: nil }
    @stats = { total_lines: 0, error_count: 0, warning_count: 0 }
  end

  def analyze
    return nil unless File.exist?(@file_path)

    line_num = 0
    File.foreach(@file_path) do |line|
      line_num += 1
      @stats[:total_lines] = line_num
      parse_line(line.strip, line_num)
    end

    generate_report
  end

  private

  def parse_line(line, line_num)
    # Parse timestamp: "May 30 10:00:00 hostname service[pid]: message"
    if line.match(/^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+(.+?):\s*(.*)$/)
      timestamp_str = $1
      hostname = $2
      service_info = $3
      message = $4

      # Update time range
      begin
        ts = Time.parse("#{timestamp_str} #{Time.now.year}")
        @time_range[:start] = ts if @time_range[:start].nil? || ts < @time_range[:start]
        @time_range[:end] = ts if @time_range[:end].nil? || ts > @time_range[:end]
      rescue
        # Skip if timestamp parsing fails
      end

      # Check for errors
      if message.match(/error|fail|critical|fatal|panic|segfault/i)
        @errors << { line: line_num, timestamp: timestamp_str, service: service_info, message: message }
        @stats[:error_count] += 1
      end

      # Check for warnings
      if message.match(/warn|warning|alert/i)
        @warnings << { line: line_num, timestamp: timestamp_str, service: service_info, message: message }
        @stats[:warning_count] += 1
      end

      # Service events (start/stop/restart)
      if message.match(/start|stop|restart|reload|systemd\[1\]/i)
        @services << { line: line_num, timestamp: timestamp_str, service: service_info, message: message }
      end

      # Authentication issues
      if message.match(/authentication failure|failed password|invalid user|sudo.*NOT IN SUDOERS/i)
        @auth_issues << { line: line_num, timestamp: timestamp_str, service: service_info, message: message }
      end
    end
  end

  def generate_report
    {
      file: @file_path,
      summary: @stats,
      time_range: {
        start: @time_range[:start]&.to_s,
        end: @time_range[:end]&.to_s
      },
      errors: @errors.first(50),  # Limit to first 50
      warnings: @warnings.first(30),
      services: @services.first(30),
      auth_issues: @auth_issues.first(20),
      error_categories: categorize_errors,
      recommendations: generate_recommendations
    }
  end

  def categorize_errors
    categories = Hash.new(0)
    @errors.each do |err|
      case err[:message]
      when /disk|io|blk|ata/i
        categories[:disk_io] += 1
      when /memory|oom|alloc/i
        categories[:memory] += 1
      when /network|eth|bond|nic|tcp|udp/i
        categories[:network] += 1
      when /auth|password|login|sudo/i
        categories[:authentication] += 1
      when /service|systemd|init/i
        categories[:services] += 1
      else
        categories[:other] += 1
      end
    end
    categories
  end

  def generate_recommendations
    recs = []
    recs << "Investigate #{@stats[:error_count]} errors found in logs" if @stats[:error_count] > 0
    recs << "Review #{@auth_issues.length} authentication failures for potential security issues" if @auth_issues.length > 5
    recs << "Check disk health - disk I/O errors detected" if categorize_errors[:disk_io] > 0
    recs << "Monitor memory usage - memory errors detected" if categorize_errors[:memory] > 0
    recs << "Check network configuration - network errors detected" if categorize_errors[:network] > 0
    recs
  end
end

# Main
if ARGV.empty?
  puts '{"error": "Usage: ruby analyze_syslog.rb /path/to/messages"}'
  exit 1
end

analyzer = SyslogAnalyzer.new(ARGV[0])
result = analyzer.analyze

if result
  puts JSON.pretty_generate(result)
else
  puts '{"error": "File not found or empty"}'
  exit 1
end

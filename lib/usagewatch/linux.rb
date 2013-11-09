# License: (MIT), Copyright (C) 2013 usagewatch Author Phil Chen, contributor Ruben Espinosa

module Usagewatch
  class Linux
    attr_accessor :ipv4_data, :ipv6_data, :meminfo_data, :net_dev_data, :disk_io_data

    def initialize
      @ipv4_data = ip_data '/proc/net/sockstat'
      @ipv6_data = ip_data '/proc/net/sockstat6'
      @meminfo_data = meminfo
      @net_dev_data = net_dev
      @disk_io_data = disk_io_parse
    end

    def refresh
      initialize
    end

    def meminfo
      `sed 's/\(.*\): *\(\d*\)/\1 \2/g' < /proc/meminfo | sed 's/kB//g'`
        .each_line.each_with_object({}) { |l,h|
          data = l.split
          h[data[0]] = data[1].to_f
        }
    end

    def df
      `df`.split(' ').map(&:to_f)
    end

    def df_total
      `df --total`.split(" ").map(&:to_f)
    end

    # Need to find out about the odd indexing here.
    def disk_used
      parts = df
      sum = (9..parts.size - 1).step(6).reduce(0) { |t, i| t += parts[i] }.round(2) 
      ((sum/1024)/1024).round(2)
    end

    # Show the percentage of disk used.
    def disk_used_percentage
      df_total[-1].round(2)
    end

    def cpu_data
      File.readlines('/proc/stat').grep(/^cpu /).first.split.map(&:to_i)
    end

    def cpu_used(proc)
      used = (1..3).reduce(0) { |t, i| t += proc[i] }.to_f
      percent (used / (used + proc[4]))
    end

    def percent(num)
      (num.to_f * 100).round(2)
    end

    def process_list(n,s='cpu')
      sort = s.eql? 'cpu' ? 2 : 3
      `ps aux | awk '{print $11, $3, $4}' | sort -k#{sort}nr  | head -n #{n} | sed 's/\[\(.*\)\]/\1/' | sed 's/.*\///'`
        .each_line.each_with_object({}){ |l, h|
          data = l.sub(':','').split
          h[data[0]] = { 'cpu' => percent(data[1]), 'ram' => percent(data[2]) }
        }
    end

    # return hash of top ten proccesses by cpu consumption
    def top_cpu_processes(n=10)
      process_list(n, 'cpu')
    end

    def ip_data(file)
      File.open(file, 'r').each_line.each_with_object({}) { |l,h|
        data = l.split
        h[data[0].sub(':','')] = data[2].to_f
      }
    end

    # Show the number of TCP connections used
    def tcp_connections
      @ipv4_data['TCP'] + @ipv6_data['TCP6']
    end

    # Show the number of UDP connections used
    def udp_connections
      @ipv4_data['UDP'] + @ipv6_data['UDP6']
    end

    # Show the percentage of Active Memory used
    def memory_used
      (@meminfo_data['Active'] / @meminfo_data['MemTotal']).round(2)
    end

    # return hash of top ten proccesses by mem consumption
    def top_processes(n)
      process_list(n, 'mem')
    end

    # Show the average system load of the past minute
    def uw_load
      percent File.open("/proc/loadavg", 'r')[1].split[1].to_f
    end

    def device_tags
      %w(wlan eth em)
    end

    def net_hash(data)
      {
        'rxbytes'   => data[1].to_f,
        'rxpackets' => data[2].to_f,
        'txbytes'   => data[9].to_f,
        'txpackets' => data[10].to_f
      }
    end

    def net_dev
      File.open("/proc/net/dev", "r").select{ |l| l =~ /^ +.+: +\d/ }
        .map{ |l| l.chomp.squeeze.lstrip.sub(':','').split }
        .each_with_object({}) { |d,h|
          h[d[0]] = net_hash(d)
        }
    end

    # Bandwidth Received Method KB
    def bandwidth_rx(dev='eth0')
      @net_dev_data[dev]['rxbytes']/1024
    end

    # Bandwidth Transmitted Method KB
    def bandwidth_tx(dev='eth0')
      @net_dev_data[dev]['txbytes']/1024
    end

    def disk_io_hash(data)
      {
        'reads_issued'    => data[3].to_i,
        'reads_merged'    => data[4].to_i,
        'sectors_read'    => data[5].to_i,
        'ms_reading'      => data[6].to_i,
        'writes_complete' => data[7].to_i,
        'writes_merged'   => data[8].to_i,
        'sectors_written' => data[9].to_i,
        'ms_writing'      => data[10].to_i,
        'current_io'      => data[11].to_i,
        'ms_io'           => data[12].to_i,
        'ms_weighted_io'  => data[13].to_i
      }
    end

    def disk_io_parse
      File.open("/proc/diskstats", "r")
        .map{ |l| l.lstrip.chomp.squeeze.split }
        .each_with_object({}){ |d,h|
          h[d[2]] = disk_io_hash(d)
      }
    end

    def disk_reads
      @disk_io_data[dev]['reads_issued']
    end

    def disk_writes
      @disk_io_data[dev]['writes_completed']
    end
  end
end

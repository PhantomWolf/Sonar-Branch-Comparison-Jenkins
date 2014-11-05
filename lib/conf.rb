#!/usr/bin/env ruby
module Tools
  def self.load_conf(name)
    path = File.join(CONF_DIR, "#{name}.conf")
    begin
      f = File.new(path)
      content = f.read
      f.close
    rescue IOError => e
      raise IOError.new("Failed to read conf file #{path}: #{e}")
    end
    # load json
    begin
      config = JSON.load(content)
    rescue => e
      raise StandardError.new("Invalid json format: #{path}")
    end
    return config
  end

  def self.load_conf(path)
    data = {}
    # read conf file
    file = File.new(path)
    content = file.read
    file.close
    # parse conf file
    content.each_line do |line|
      key, value = line.strip.split
      if ['"', "'"].include?(value[0].chr) and ['"', "'"].include?(value[-1].chr)
        value = value[1..-2]
      elsif ['"', "'"].include?(value[0].chr)
        value = value[1..-1]
      elsif ['"', "'"].include?(value[-1].chr)
        value = value[0..-1]
      end
      data[key] = value
    end
    return data
  end

  def self.load_tmpl(name)
    path = File.join(TMPL_DIR, "#{name}.tmpl")
    begin
      f = File.new(path)
      tmpl = f.read
      f.close
    rescue IOError => e
      raise IOError.new("Failed to read template file: #{path}")
    end
    return tmpl
  end
end

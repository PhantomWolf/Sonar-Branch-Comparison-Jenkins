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

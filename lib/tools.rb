#!/usr/bin/env ruby
require 'ostruct'

module Tools
  def self.load_conf(name)
    path = File.join(CONF_DIR, "#{name}.conf")
    begin
      f = File.new(path)
      config = JSON.load(f)
      f.close
    rescue IOError => e
      raise IOError.new("Failed to read conf file #{path}: #{e}")
    rescue JSON::ParserError => e
      raise JSON::ParserError.new("Invalid json file #{path}: #{e}")
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

  def self.load_env(hash, optional=false)
    result = {}
    hash.each_pair do |key, value|
      if not optional and ENV[value].nil?
        raise ArgumentError.new("Environment variable '#{value}' isn't set!")
      end
      result[key] = ENV[value]
    end
    return result
  end

  def self.hash_to_ostruct(hash)
    os = OpenStruct.new
    hash.each_pair do |key, value|
      os[key.to_sym] = value
    end
    return os
  end
end

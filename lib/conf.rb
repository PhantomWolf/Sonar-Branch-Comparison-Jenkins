#!/usr/bin/env ruby
module Config
  def self.load(path)
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
end

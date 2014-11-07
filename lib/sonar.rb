#!/usr/bin/env ruby
require 'tools'
require 'gerrit'


METRICS = {
  'line' => ['ncloc', 'statements', 'files', 'classes', 'functions', 'lines'],
  'issue' => ['blocker_violations', 'critical_violations', 'major_violations', 'minor_violations',
              'info_violations', 'violations', 'violations_density'],
  'comment' => ['comment_lines', 'comment_lines_density'],
  'duplication' => ['duplicated_lines', 'duplicated_lines_density', 'duplicated_blocks', 'duplicated_files'],
  'complexity' => ['function_complexity', 'class_complexity', 'file_complexity', 'complexity'],
}

class SonarComparison
  # config - a Hash containing necessary info to start an sonar branch comparison:
  #           :sonar_url        url of the sonar server
  #           :project_key      key of the project
  #           :base_branch      branch of the base project, generally "master"
  #           :target_branch    branch of the target project
  attr_reader :result

  @@email_tmpl = Tools::load_tmpl('email_body')
  @@tbody_tmpl = Tools::load_tmpl('_email_tbody_line')

  def initialize(config)
    @server_url = config[:sonar_url]
    @project_key = config[:project_key]
    @base_branch = config[:base_branch]
    @target_branch = config[:target_branch]
    @url = self.get_url('json')
  end

  def get_url(format=nil)
    url = "#{@server_url}/branch_comparison/result/#{@project_key}:#{@base_branch}?target=#{@project_key}:#{@target_branch}"
    url << "&format=#{format}" unless format.nil?
    return url
  end

  def run
    res = Rest::get(@url)
    if res.status_code < 200 or res.status_code >= 300
      raise StandardError.new("HTTP #{res.status_code}: failed to get comparison result\n#{res.text}")
    end
    @result = JSON.load(res.text)
    return @result
  end

  def to_html
    tbody = ''
    METRICS.each_pair do |category, array|
      array.each do |metric_name|
        data = @result[metric_name]
        if data['quality'] == 1
          quality = 'better'
        elsif data['quality'] == -1
          quality = 'worse'
        else
          quality = 'neutral'
        end
        if data['delta']
          delta = "(#{data['delta']})"
        else
          delta = nil
        end
        item = @@tbody_tmpl % {:quality => quality,
                              :metric_short_name => data['short_name'],
                              :base_data => data['base'],
                              :target_data => data['target'],
                              :delta => delta}
        tbody << item
      end
    end
    email = @@email_tmpl % {:base_branch => @base_branch,
                            :target_branch => @target_branch,
                            :url => @url,
                            :tbody => tbody}
    return email
  end

  def review_value
    if @result['blocker_violations']['quality'] < 0 or @result['critical_violations']['quality'] < 0
      return -1
    else
      return 1
    end
  end
end

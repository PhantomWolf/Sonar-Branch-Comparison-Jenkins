#!/usr/bin/env ruby
require 'tools'

module Sonar
  def self.gen_comparison_result_url(sonar_url, base_project_key, target_project_key, format=nil)
    url = "#{sonar_url}/branch_comparison/result/#{base_project_key}?target=#{target_project_key}"
    url << "&format=json" unless format.nil?
    return url
  end

  def self.comparison_to_email(base_branch, target_branch, measure_data, url)
    email_tmpl = Tools::load_tmpl('email_body')
    item_tmpl = Tools::load_tmpl('_email_tbody_line')
    tbody = ''
    METRICS.each_pair do |category, array|
      array.each do |item|
        metric_name = item[:name]
        data = @measure_data[metric_name]
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
        metric = Metric.by_name(metric_name)
        item = item_tmpl % {:quality => quality,
                            :metric_short_name => metric.short_name,
                            :base_data => data['base'],
                            :target_data => data['target'],
                            :delta => delta}
        tbody << item
      end
    end
    email = email_tmpl % {:base_branch => base_branch,
                          :target_branch => target_branch,
                          :url => url,
                          :tbody => tbody}
    return email
  end

  def self.analyze_comparison(measure_data)
    if measure_data['blocker_violations']['quality'] < 0 or measure_data['critical_violations']['quality'] < 0
      review = -1
    else
      review = 1
    end
    return review
  end
end

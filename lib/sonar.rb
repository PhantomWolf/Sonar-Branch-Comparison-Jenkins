#!/usr/bin/env ruby
module Sonar
  def self.gen_comparison_result_url(sonar_url, base_project_key, target_project_key, format=nil)
    url = "#{sonar_url}/branch_comparison/result/#{base_project_key}?target=#{target_project_key}"
    url << "&format=json" unless format.nil?
    return url
  end

  def self.comparison_to_html(base_project, target_project, measure_data)
    item_tmpl = File
    tbody = ''


    thead = <<END
<tr>
  <td>#</td>
  <td>#{base_project.branch.to_s}</td>
  <td>#{target_project.branch.to_s}</td>
</tr>
END

    tbody = ''
    METRICS.each_pair do |category, array|
      array.each do |item|
        metric_name = item[:name]
        data = @measure_data[metric_name]
        if data['quality'] == 1
          quality = ' class="better"'
        elsif data['quality'] == -1
          quality = ' class="worse"'
        else
          quality = nil
        end
        if data['delta']
          delta = "(#{data['delta']})"
        else
          delta = nil
        end
        metric = Metric.by_name(metric_name)
        tbody << "<tr#{quality}><td class=\"metric_name\">#{metric.short_name}</td><td class=\"data\">#{data['base']}</td><td class=\"data\">#{data['target']}#{delta}</td></tr>\n"
      end
    end
    link_text = "View comparison result on sonar website"
    result_url = "http://#{request.host}:#{request.port}/branch_comparison/result/#{base_project.id}?target=#{target_project.id}"

    html = html_template % {:css => css, :thead => thead, :tbody => tbody, :result_url => result_url, :link_text => link_text}
    return html
  end

  def self.analyze_comparison(data)
    if @measure_data['blocker_violations']['quality'] < 0 or @measure_data['critical_violations']['quality'] < 0
      review = -1
    else
      review = 1
    end
    return review
  end
end

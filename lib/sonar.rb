#!/usr/bin/env ruby
module Sonar
  def self.gen_comparison_result_url(sonar_url, base_project_key, target_project_key, format=nil)
    url = "#{sonar_url}/branch_comparison/result/#{base_project_key}?target=#{target_project_key}"
    url << "&format=json" unless format.nil?
    return url
  end

  def self.comparison_to_html(base_project, target_project, measure_data)
    css = <<END
<style type="text/css">
  .metric_name {
    width: 20em;
    overflow: hidden;
    border-left: 1px solid;
    border-right: 1px solid;
  }
  .data {
    width: 10em;
    border-right: 1px solid;
  }
  .better {
    background-color: #40FF00;
  }
  .worse {
    background-color: #FE2E2E;
  }
  td {
      text-align: center;
      border-bottom: 1px solid;
  }
</style>
END
    html_template = <<END
<html>
  <head>
    %{css}
  </head>
  <body>
    <table>
      <thead>
        %{thead}
      </thead>
      <tbody>
        %{tbody}
      </tbody>
    </table>
    <a href="%{result_url}">%{link_text}</a>
  </body>
</html>
END
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

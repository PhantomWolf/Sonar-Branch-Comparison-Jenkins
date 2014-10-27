#!/usr/bin/env ruby
ENV_MAP = {
  'sonar.projectKey' => 'SONAR_PROJECT_KEY',
  'sonar.projectName' => 'SONAR_PROJECT_NAME',
  'sonar.projectVersion' => 'SONAR_PROJECT_VERSION',
  'sonar.sources' => 'SONAR_SOURCES',
  'sonar.language' => 'SONAR_LANGUAGE',
  'sonar.revision' => ['GERRIT_BRANCH', 'GERRIT_REFNAME']
}

if __FILE__ == $0
end

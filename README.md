# Sonar Branch Comparison - Jenkins part
## Arguments(Environment variables)
- SONAR_ARGS:               custom arguments for sonar runner command
- SONAR_PROJECT_KEY:        id of the project in sonar server
- SONAR_PROJECT_NAME:       project name
- SONAR_PROJECT_VERSION:    project version
- SONAR_SOURCES:            directories which holds source codes
- SONAR_LANGUAGE:           programming language used by the project
- SONAR_HOST_URL:           url of sonar server
- SONAR_JDBC_URL:           jdbc url of the database
- SONAR_JDBC_USERNAME:      database username
- SONAR_JDBC_PASSWORD:      database password
- BASE_BRANCH:              the base branch of the project. Other branches will be compared with it.
- GERRIT_URL:               url of gerrit server
- GERRIT_USERNAME:          gerrit username
- GERRIT_PASSWORD:          gerrit password

## Branch comparison flowchart
![Branch comparison flowchart](static/flowchart.png)
## Classes/Modules
### Gerrit
Rest api library for gerrit server

### Sonar
Library for getting/parsing sonar branch comparison results

### Tools
Functions for loading templates, environment variables, etc.

### Email(deprecated)
Sending emails using local SMTP server

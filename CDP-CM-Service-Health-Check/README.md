# Service Health Check

This script checks the status of several services through API and systemctl commands, and collects their logs if they are not running or in poor health. The services that are checked are:

    Nginx
    Cloudera Manager (CM) server and CM agent
    Knox service

## Prerequisites

This script needs to run from the Cloudera Manager node as root. You also need to provide your Workload user and password to authenticate with the Cloudera Manager API.
Usage

    Make the script executable:

`$ chmod +x service_health_check.sh`

    Run the script:

`$./service_health_check.sh`

The script will prompt you to enter your Workload username and password.

## Output

The script will print messages to the console indicating the status of each service. If a service is not running or in failed state, the script will collect its logs and save them to a compressed file in the /tmp directory. The file name will be in the format service-name-log-files-hostname_date-time.tgz.

## Color Codes

The script uses color codes to highlight the status of each service:

    Red (31) for errors or failed services
    Green (32) for successful services
    Cyan (36) for information messages

## Version

This is version 1.1 of the script.

## Authors

    Shehbaz (original author)
    Raman (modifier)

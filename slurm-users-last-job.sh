#!/bin/bash
# Cluster Tools: A suite of tools, files and scripts to assist on a HPC cluster.
# Copyright (C) 2021 ARCC: University of Wyoming: https://www.uwyo.edu/arcc/
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

VERSION=0.2

function err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

function log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

function usage() {
  echo "Usage: command [ -s START_DATE(MM/DD/YY) ] [ -o OUTPUT_FILENAME ] [-n] [-h] [-v] CLUSTER [ACTIVE_PROJECT_FILE]" 1>&2
}

function exit_abnormal() {
  usage
  exit 1
}

###############################
# A a short pause/sleep to the script.
# The intention is to not overload the slurm controller and throttle calls.
###############################
function pause() {
  sleep 0.25
}

###############################
# Check that the defined cluster argument is a defined within slurm.
# Arguments:
#   Name of the cluster to check for, a string.
# Returns:
#   String of true/false defining if cluster is valid.
###############################
function check_cluster_is_valid() {
  local cluster=$1
  local slurm_result
  slurm_result=$( sacctmgr list cluster format=cluster -nP )
  is_cluster_valid=false
  for item in $slurm_result
  do
    if [ "$cluster" == "$item" ]; then
      is_cluster_valid=true
      break
    fi
  done
  pause
  echo $is_cluster_valid
}

###############################
# Check that the defined start date argument is valid.
# Arguments:
#   start date to validate, a date.
# Outputs:
#   No output - will exit if date is invalid.
###############################
function is_start_date_valid() {
  local start_date=$1
  if date -d "$start_date" >/dev/null 2>&1; then
    current_date="$(date +'%D')"
    current_date_sec=$(date -d "$current_date" +'%s')
    start_date_sec=$(date -d "$start_date" +'%s')
    if [[ "$start_date_sec" -ge "$current_date_sec" ]]; then
      err "ERROR: Start Date $start_date can not be greater than or equal to the current date $current_date."
      exit 1
    fi
  else
    err "ERROR: Start Date $start_date is not valid - format needs to be MM/DD/YY"
    exit 1
  fi
}

###############################
# Check that the defined start date argument is valid.
# Arguments:
#   start date to validate, a date.
# Outputs:
#   No output - will exit if date is invalid.
###############################
function get_list_of_projects_in_cluster() {
  local cluster=$1
  local slurm_result
  slurm_result=$( sacctmgr list associations cluster="$cluster" format=Account -nP | sort | uniq )
  pause
  echo "$slurm_result"
}

###############################
# For the define project and user find the last job they have submitted
# since the defined start date.
# Arguments:
#   project the user is associated with, a string.
#   username of the user to check for, a string.
# Outputs:
#   Returns a string prefixed with the project name and username,
#   and appended with the last job details of found.
###############################
function find_last_job_for_user_within_project() {
  local project=$1
  local username=$2
  local result_str="$project,$username"

  local slurm_result
  slurm_result=$( sacct -A "$project" -u "$username" -S "$START_DATE" --format="JobID,State,Start,End" -nPX --delimiter=,)
  if [ -n "${slurm_result}" ]; then
    last_job="${slurm_result##*$'\n'}"
    result_str="$result_str,Y,$last_job"
  else
    result_str="$result_str,N,,,,"
  fi
  pause
  echo "$result_str"
}

###############################
# Check that the defined start date argument is valid.
# Globals:
#    OUTPUT_RESULTS
# Arguments:
#   start date to validate, a date.
# Outputs:
#   No output - appends results to the OUTPUT_RESULTS global variable.
###############################
function find_project_users() {
  local cluster=$1
  local project=$2
  local slurm_result
  slurm_result=$( sacctmgr list associations account="$project" cluster="$cluster" format=User -nP )
  for username in $slurm_result; do
    if [ -n "${username}" ]; then
      local result_str
      result_str=$(find_last_job_for_user_within_project "$project" "$username")
      OUTPUT_RESULTS=$OUTPUT_RESULTS$result_str$'\n'
    fi
  done
  pause
}

###############################
# Validate the command line options.
# Globals:
#   START_DATE
#   OUTPUT_FILENAME
#   CLUSTER
#   ACTIVE_PROJECT_FILE
# Outputs:
#   No output - will exit if any argument is invalid and can not have a default defined.
###############################
function validate_options() {
  if [ -z "${START_DATE}" ]; then
    START_DATE=$(date +'%D' --date "-1 year")
    err "WARNING: START_DATE undefined. Using default of one year from today: $START_DATE"
  else
    is_start_date_valid "$START_DATE"
  fi

  if [ -z "${OUTPUT_FILENAME}" ]; then
    OUTPUT_FILENAME="output.csv"
    err "WARNING: No output filename defined. Using default of $OUTPUT_FILENAME"
  fi

  if [ -z "${CLUSTER}" ]; then
    err "ERROR: A cluster value must be defined."
    exit 1
  else
    local valid_cluster
    valid_cluster=$(check_cluster_is_valid "$CLUSTER")
    if [ "$valid_cluster" = false ] ; then
      err "ERROR: The defined cluster '$CLUSTER' is not valid."
      exit 1
    fi
  fi

  if [ -z "${ACTIVE_PROJECT_FILE}" ]; then
    err "WARNING: No active project file value must be defined. Will check against ALL accounts."
    ALL_ACCOUNTS=1
  else
    if ! [ -e "${ACTIVE_PROJECT_FILE}" ]; then
      err "ERROR: The defined active project file '$ACTIVE_PROJECT_FILE' does not exist."
      exit 1
   fi
 fi
}

COLUMN_HEADERS=true
OUTPUT_RESULTS="project,username,has_job,jobid,status,start,end"$'\n'

while getopts :s:o:nhv opt; do
  case "${opt}" in
    s)
      START_DATE=${OPTARG}
      ;;
    o)
      OUTPUT_FILENAME=${OPTARG}
      ;;
    n)
      COLUMN_HEADERS=false
      OUTPUT_RESULTS=""
      ;;
    h)
      usage
      exit 0
      ;;
    v)
      echo "Version: "$VERSION
      exit 0
      ;;
    :)
      err "ERROR: -${OPTARG} requires an argument."
      exit_abnormal
      ;;
    \?)
      err "ERROR: Invalid option: '$OPTARG'"
      exit_abnormal
      ;;
  esac
done

shift $(($OPTIND -1))

CLUSTER=$1
ACTIVE_PROJECT_FILE=$2
ALL_ACCOUNTS=0
validate_options

log "Command Line Options:"
log "Active Project File: $ACTIVE_PROJECT_FILE"
log "Cluster: $CLUSTER"
log "Start Date: $START_DATE"
log "Output Filename: $OUTPUT_FILENAME"
log "Include headers in output: $COLUMN_HEADERS"
log "- - - - - - - - -"

LIST_OF_PROJECTS=$(get_list_of_projects_in_cluster "$CLUSTER")
num_of_projects=0

if [[ "$ALL_ACCOUNTS" -eq 1 ]]; then
  log "Checking ALL accounts."
  {
    while IFS=, read -r project_name || [ -n "$project_name" ]; do
      if [ -n "${project_name}" ]; then
        ((num_of_projects++))
        log "$num_of_projects: $project_name"
        find_project_users "$CLUSTER" "$project_name"
      fi
    done
    log "Processed $num_of_projects projects."
  } <<< "$LIST_OF_PROJECTS"
else
  {
    log "Processing active project file:"
    while IFS=, read -r project_name || [ -n "$project_name" ]; do
      if [ -n "${project_name}" ]; then
        ((num_of_projects++))
        log "$num_of_projects: $project_name"

        if [[ "$LIST_OF_PROJECTS" =~ .*"$project_name".* ]]; then
          find_project_users "$CLUSTER" "$project_name"
        else
          err "WARNING: '$project_name' is not a valid project on cluster '$CLUSTER'."
        fi
      fi
    done
    log "Processed $num_of_projects projects."
  } < "$ACTIVE_PROJECT_FILE"
fi
echo "$OUTPUT_RESULTS" | tee "$OUTPUT_FILENAME" >/dev/null
log "Output results saved to $OUTPUT_FILENAME"
log "Done."
exit 0

# slurm-users-last-job
This is a helper script to find when a user last ran a job within a particular project
on a cluster platform that uses Slurm Workload Manager.

## ARCC
ARCC is the Advanced Research Computing Center at the University of Wyoming.

Contact information can be found on our web page: https://www.uwyo.edu/arcc/


## Design Goals
One of the main goals is to keep the script as simple as possible with respect to
required applications.

From a very high level this is a bash script that makes calls to Slurm to retrieve 
required account/user and usage data. Its basic usage is to read a file that lists 
the accounts/projects to inspect the users within, and generate a comma delimited 
output file that lists their last ran job.

Its intention is to be used as a step within a longer workflow. For example a previous
step could possibly generate the project list file from say an IDM type application,
and a later step reads the output file into a metrics/reporting related application.

## Installation
The script does not require any specific installation steps.

It has been developed and tested on a platform using: 
`GNU bash, version 4.2.46(2)-release (x86_64-redhat-linux-gnu)`

## Usage
`Usage: command [ -s START_DATE(MM/DD/YY) ] [ -o OUTPUT_FILENAME ] [-n] [-h] [-v] CLUSTER ACTIVE_PROJECT_FILE`

Optional:

* `-s` define a start date to look for submitted jobs after. If not defined then 
  the default is to set as one year prior to the current date.
* `-o` define the name of the output file. If not defined then output.csv' will 
  be used as the default.
* `-n` use if you do not wish the column header names to be written to the output 
  file.  
* `-h` write to the command line the general usage.
* `-v` write to the command the current script version.

Required:
* `CLUSTER` this is the name of a configured SSlurm cluster to check projects against.
* `ACTIVE_PROJECT_FILE` this is the path/name to a file that lists the names of the 
  projects (or accounts using Slurm terminology) to check for users within against.
  It takes the format of listing one project per line.

Example:
```
project_name_1
project_name_2
project_name_3
```

### Example
```
bash slurm-users-last-job.sh -s 07/01/21 -o july_2021.csv teton projects.txt
```

## Issues
Within our center we have methods to remove users from projects and accounts.
Although these tidy up our system, it does not remove them from Slurm.

A removed user listed within slurm, associated with a project, will report the
following message: `Invalid user id: <username>`


# jira-cli
Tool for extracting issue data from Jira.

## Setup
1) Ensure ruby 2.3 is installed
2) Create a 'config' directory in the root and add a 'credentials.yml' file to it. The credentials file should contain 'username' and 'password' keys filled in with a valid Jira user. **Note: if you're using a single sign-on e.g. Google apps, you'll need to create a password for your user apart from the one you use with your Google sign-in.**

## Args
- -c computes and produces cycle times data

## Usage
Run the script with the args of your choice:

*ruby pui_sprints.rb [args]*

A file named *pui_sprint_report_results.csv* will be produced in the root directory. IF you run the *-c* option, it will produce *pui_sprint_cycle_times.csv* and *pui_sprint_results_changelog.csv* in the root directory.

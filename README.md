# jira-cli
Tool for extracting issue data from Jira.

## Setup
1) Ensure ruby 2.3 is installed
2) Create a 'config' directory in the root and add a 'credentials.yml' file to it. The credentials file should contain 'username' and 'password' keys filled in with a valid Jira user. **Note: if you're using a single sign-on e.g. Google apps, you'll need to create a password for your user apart from the one you use with your Google sign-in.**

## Args
- -l produces changelog information for issues
- -c computes and produces cycle times data

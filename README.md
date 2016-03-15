Jira Notifier
---------------------

TABLE OF CONTENTS
 * Introduction
 * Requirements
 * Recommended modules
 * Installation
 * Configuration



INTRODUCTION

 This project was created to post Jira searches into Slack channels.

REQUIREMENTS
 * gem json

RECOMMENDED MODULES
 * cron

INSTALLATION
* Download jira-notifier.rb and example.json into a folder

CONFIGURATION
* Make a copy of example.json and fill in the fields with your information. Example file ideas:
 * hourly.json
 * daily.json
 * Weekly.json
* The notifier can now be run by using the command './jira-notifier [yourfile.json]'
* To extend functionality it is reccomended to set up recuring notifications by using cron.
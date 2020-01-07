MongoSwift release process
============================

1. Ensure all the JIRA tickets for this release are resolved. You can find the releases on [this page](https://jira.mongodb.org/projects/SWIFT?selectedItem=com.atlassian.jira.jira-projects-plugin:release-page&status=unreleased).
1. From the base directory of the project, run `etc/release.sh` with the new version, e.g. `./etc/release.sh 1.0.0`.
1. The release script should have taken you to the GitHub page for the tag.
    - Click "Edit Tag".
    - Add a title, "MongoSwift [version here]".
    - Add a description. See [previous release notes](https://github.com/mongodb/mongo-swift-driver/releases/tag/v0.1.0) for an example of what this looks like. You can use the JIRA "Release Notes" HTML as a starting point.
    - Click "Publish release".
1. Mark the release as published on JIRA.
1. Send a message to the #swift Slack channel.

import re
import requests
import sys

# This script accepts a version number in the form "x.y" as an argument. It will query the Swift Github
# repo for releases and find the latest x.y.z patch release if available, and print out the matching tag.

if len(sys.argv) != 2:
    print("Expected 1 argument, but got: {}".format(sys.argv[1:]))
    exit(1)

version = sys.argv[1]
components = version.split('.')
if len(components) != 2:
    print("Expected version number in form x.y, got {}".format(version))
    exit(1)

major = components[0]
minor = components[1]

version_regex = '^swift-{}\.{}(\.\d+)?-RELEASE$'.format(major, minor)

release_data = requests.get('https://api.github.com/repos/apple/swift/releases').json()
tag_names = map(lambda release: release['tag_name'], release_data)

matching_tags = sorted(filter(lambda tag: re.match(version_regex, tag) is not None, tag_names), reverse=True)
if len(matching_tags) == 0:
    print("No tags matching {} found".format(version))
    exit(1)

# full name is swift-x.y.z-release, drop the prefix and suffix.
tag_split = matching_tags[0].split('-')
print(tag_split[1])

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

version_regex = '^swift-({}\.{}(\.(\d+))?)-RELEASE$'.format(major, minor)

release_data = requests.get('https://api.github.com/repos/apple/swift/releases').json()
tag_names = map(lambda release: release['tag_name'], release_data)

# find tags matching the specified regexes
matches = filter(lambda match: match is not None, map(lambda tag: re.match(version_regex, tag), tag_names))

# sort matches by their patch versions. patch versions of 0 are omitted so substitute 0 when the group is None.
sorted_matches = sorted(matches, key=lambda match: int(match.group(2)[1:]) if match.group(2) is not None else 0, reverse=True)

# map to the first match group which contains the full version number.
sorted_version_numbers = map(lambda match: match.group(1), sorted_matches)
print(next(sorted_version_numbers))

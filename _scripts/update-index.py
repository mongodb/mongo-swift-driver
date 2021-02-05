import os

first=True
with open('./docs/index.md', 'w') as f:
    f.write('# MongoSwift Documentation Index\n')

    for dir in sorted(os.listdir('./docs'), reverse=True):
        if not dir[0].isdigit():
            continue

        version_str = dir
        if first:
            version_str += ' (current)'
            dir = 'current'
            first = False

        f.write('- [{}]({}/MongoSwift/index.html)\n'.format(version_str, dir))

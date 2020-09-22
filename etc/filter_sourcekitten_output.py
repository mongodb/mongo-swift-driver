import json

# use Exports.swift as the canonical list of re-exported symbols we need to document.
with open('./Sources/MongoSwiftSync/Exports.swift') as f:
    lines = list(f)

reexported_symbols = set()
for line in filter(lambda x: x.startswith("@_exported"), lines):
    symbol = line.split(".")[-1][:-1]
    reexported_symbols.add(symbol)

# function names show up differently in the export list and in the SourceKitten output
reexported_symbols.add("cleanupMongoSwift()")

# for each module, SourceKitten generates a JSON file containing an array where each
# element corresponds to a Swift file. here we go through the files and for each of
# them filter the data so they only contain the symbols we want to re-export.

with open('mongoswift-docs.json') as f:
    original_data = json.load(f)

for swift_file in original_data:
    # each file is an object with a single key, where the key is the file name.
    file_name = list(swift_file.keys())[0]

    symbols = swift_file[file_name]['key.substructure']
    swift_file[file_name]['key.substructure'] = [s for s in symbols if s['key.name'] in reexported_symbols]

# write the filtered data back to a JSON file.
with open('mongoswift-filtered.json', 'w') as json_file:
    json.dump(original_data, json_file)

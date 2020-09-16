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
output_files = []

with open('mongoswift-docs.json') as f:
    original_data = json.load(f)

for swift_file in original_data:
    # each file is an object with a single key, where the key is the file name.
    file_name = list(swift_file.keys())[0]
    
    filtered_symbols = []
    # key.substructure is an array with one element per symbol in the file.
    for symbol in swift_file[file_name]['key.substructure']:
        symbol_name = symbol['key.name']
        # the symbol name for cleanupMongoSwift() 
        if symbol_name in reexported_symbols:
            filtered_symbols.append(symbol)

    # make a copy of the file, which we will update with our filtered data.
    filtered_file = swift_file
    filtered_file[file_name]['key.substructure'] = filtered_symbols

    output_files.append(filtered_file)

# write the filtered data back to a JSON file.
with open('mongoswift-filtered.json', 'w') as json_file:
  json.dump(output_files, json_file)

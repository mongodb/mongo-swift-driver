import json

with open('Package.resolved', 'r') as f:
    data = json.load(f)
    bson_data = next(d for d in data['object']['pins'] if d['package'] == 'swift-bson')
    print(bson_data['state']['version'])

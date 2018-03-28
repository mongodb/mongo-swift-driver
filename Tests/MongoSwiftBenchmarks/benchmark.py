import re
import sys

# this script should be run from the root project directory with:
# `make benchmark | python Tests/MongoSwiftBenchmarks/benchmark.py`
output = sys.stdin.read()
results = filter(lambda x: "median time" in x, output.split('\n'))

benchmarks = {}
for r in results:
	match = re.search(r"\[.*\ (?P<name>.*)]: median time (?P<seconds>.*) seconds, score (?P<score>.*) ", r)
	name = match.group("name")
	time = match.group("seconds")
	score = match.group("score")
	benchmarks[name] = {"time": float(time), "score": float(score)}

print benchmarks



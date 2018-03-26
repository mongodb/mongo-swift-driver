import re
import sys

# this script should be run from the root project directory with:
# `make benchmark 2>&1 | python Tests/MongoSwiftBenchmarks/benchmark.py`
# the test results go to stderr so the 2>&1 is to redirect stderr to stdout.
# output = sys.stdin.read()
# results = filter(lambda x: "Median time" in x or "Score" in x, output.split('\n'))

results = ["Results for for -[MultiDocumentBenchmarks testFindManyAndEmptyCursor]: median time 0.022 seconds, score 705.7451 MB/s"]

benchmarks = {}
for r in results:
	match = re.search(r"\[.*\ (?P<name>.*)]: median time (?P<seconds>.*) seconds, score (?P<score>.*) ", r)
	name = match.group("name")
	time = match.group("seconds")
	score = match.group("score")
	print name
	print time
	print score
	#avg = re.search(r"average: .*?,", r).group(0)[9:-1]
	#benchmarks[name] = float(avg)

print benchmarks



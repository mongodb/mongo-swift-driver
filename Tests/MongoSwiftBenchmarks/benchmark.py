import re
import sys

# this should be run from the root project directory with:
# `make benchmark 2>&1 | python Tests/MongoSwiftBenchmarks/benchmark.py`
# the test results go to stderr so the 2>&1 is to redirect stderr to stdout.
output = sys.stdin.read()
results = filter(lambda x: "measured" in x, output.split('\n'))

benchmarks = {}
for r in results:
	name = re.search(r"\[.*?\]", r).group(0)[22:-1]
	avg = re.search(r"average: .*?,", r).group(0)[9:-1]
	benchmarks[name] = float(avg)

print benchmarks



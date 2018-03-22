import sys
import re

results = [line for line in sys.stdin.read().split('\n') if "measured" in line]

benchmarks = {}

for r in results:
	name = re.search(r"\[.*?\]", r).group(0)[22:-1]
	avg = re.search(r"average: .*?,", r).group(0)[9:-1]
	benchmarks[name] = float(avg)

print benchmarks



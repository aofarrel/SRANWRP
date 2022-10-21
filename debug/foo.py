with open("working.txt") as f:
	for a in f.readlines():
		in_g = 0
		with open("full.txt") as g:
			for b in g.readlines():
				if a == b:
					in_g = 1
			if in_g == 0:
				print(f"{a} not in full.txt")
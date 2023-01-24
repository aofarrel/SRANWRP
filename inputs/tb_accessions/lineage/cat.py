import os
with open("all_lineages", "w") as catfile:
	files = [file for file in os.listdir(".") if file.endswith(".txt")]
	for file in files:
		with open(file, "r") as lineagefile:
			for line in lineagefile.readlines():
				line = line.strip("\n")
				catfile.write(f"{line}\t{file.strip('.txt')}\n")

os.system("touch all_unique")
os.system("sort all_lineages | uniq -u >> all_unique")
# cat all lineage files into one file
import os
with open("all_lineages", "w") as catfile:
	files = [file for file in os.listdir(".") if file.endswith(".txt")]
	for file in files:
		with open(file, "r") as lineagefile:
			for line in lineagefile.readlines():
				line = line.strip("\n")
				catfile.write(f"{line}\t{file.strip('.txt')}\n")

os.system("sort all_lineages >> all_sorted")
#os.system("uniq -u all_sorted >> all_unique")
os.system("cut -f1 all_sorted >> all_samples_only")
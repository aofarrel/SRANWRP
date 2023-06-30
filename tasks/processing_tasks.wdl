version 1.0

# These are tasks that synergize with the other tasks in this repo, but do not
# query SRA (or any other NCBI platform) directly.

task extract_accessions_from_file {
	# Convert txt file of a list of bioproj/biosamp/run accessions, one accession
	# per newline (except for some blank lines), into an Array[String].
	# This allows us to work with NCBI web search's "send to file" output
	# more easily with WDLs. We can't just use WDL's built in "read_lines"
	# as the blank lines NCBI throws in would cause issues.
	#
	# This can also handle the situation where xtract gives us tab-seperated
	# accessions all on the same line.
	input {
		# It doesn't matter if the input file is sorted by organism or 
		# uses NCBI's "default order." Either works.
		File accessions_file
		Int preempt = 1
		Boolean filter_na = true
	}
	Int disk_size = ceil(size(accessions_file, "GB")) * 2

	command <<<
	sort "~{accessions_file}" | uniq -u > unique.txt
	python3 << CODE
	import os
	f = open("unique.txt", "r")
	valid = []
	for line in (f.readlines()):
		if line == "":
			pass
		elif line == "NA" and "~{filter_na}" == "true":
			print("WARNING -- NA found")
			pass
		else:
			split = line.split("\t")
			for accession in split:
				valid.append(accession.strip("\n")+"\n")
	f.close()
	os.system("touch valid.txt")
	g = open("valid.txt", "a")
	g.writelines(valid)
	g.close()
	CODE
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[String] accessions = read_lines("valid.txt")
	}
}

task cat_strings {
	# Concatenate Array[String] into a single File.

	input {
		Array[String] strings
		String out = "pull_reports.txt"
		Int disk_size = 10
	}

	command <<<
		printf "~{sep='\n' strings}" > "~{out}"
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: 2
	}

	output {
		File outfile = out
	}
}

task cat_files {
	# Concatenate Array[File] into a single File.
	#
	# Files going into removal_candidates should be formatted as TSVs
	# where the first column is the filename and the second column is
	# a float value. (Other columns will be ignored.) These TSVs will
	# be cat to create a single big TSV. Then, any values ABOVE the
	# user-input float removal_threshold will have their associated
	# file removed, preventing it from being cat'd. In other words,
	# this is a lowpass filter.
	#
	# For example:
	# files = [SAMEA10030079.diff, SAMEA7555065.diff]
	# removal_candidates = [SAMEA10030079.report, SAMEA7555065.report]
	# removal_threshold = 0.02
	#
	# Let's say SAMEA10030079.report looked like this:
	# SAMEA10030079.diff	0.02230766998856633
	#
	# And SAMEA7555065.report looked like this
	# SAMEA7555065.diff	0.019289670799169087
	#
	# First, the reports would get cat into this:
	# SAMEA10030079	0.02230766998856633
	# SAMEA7555065	0.019289670799169087
	#
	# Then, the script would notice that SAMEA10030079 has a value above
	# the removal_threshold of 0.02, so it deletes the SAMEA10030079.diff
	# input. As a result, the final cat file will only consist of
	# SAMEA7555065.diff.

	input {
		Array[File] files
		Array[File]? removal_candidates
		Float removal_threshold = 0.05
		String out_filename = "all.txt"
		Int preempt = 1
		Boolean keep_only_unique_lines = false
		Boolean output_first_lines = true
		Boolean strip_first_line_first_char = true
		String first_lines_out_filename = "firstlines.txt"
		Boolean verbose = false
	}
	Int disk_size = ceil(size(files, "GB")) * 2
	Int number_of_files = length(files)

	command <<<

	if [[ ! "~{sep=' ' removal_candidates}" = "" ]]
	then
		echo "Checking which files ought to not be included..."
		cat ~{sep=" " removal_candidates} >> removal_guide.tsv
		FILES=(~{sep=" " files})
		for FILE in "${FILES[@]}"
		do
			# check if it's in the removal guide and below threshold
			basename_file=$(basename "$FILE")
			this_files_info=$(awk -v file_to_check="$basename_file" '$1 == file_to_check' removal_guide.tsv)
			baseroot_file=$(basename -s ".diff" "$FILE")
			echo "$this_files_info" > temp
			if [[ ! "$this_files_info" = "" ]]
			then
				# okay, we have information about this file. is it above the removal threshold?
				# piping an inequality to `bc` will return 0 if false, 1 if true
				this_files_value=$(cut -f2 temp)
				is_bigger=$(echo "$this_files_value>~{removal_threshold}" | bc) 
				if [[ $is_bigger == 0 ]]
				then
					# this_files_value is below the removal threshold and passes
					cat "$FILE" >> "~{out_filename}"
					if [[ "~{verbose}" = "true" ]]
					then
						echo "$FILE added."
					fi

					# now, check if we're grabbing first lines (for diffs, this means samples)
					if [[ "~{output_first_lines}" = "true" ]]
					then
						touch "~{first_lines_out_filename}.txt"
						if [[ "~{strip_first_line_first_char}" = "true" ]]
						then
							firstline=$(head -1 "$FILE")
							echo "${firstline:1}" >> "~{first_lines_out_filename}.txt"
						else
							head -1 "$FILE" >> "~{first_lines_out_filename}.txt"
						fi
					fi
				
				else
					# this_files_value is above the removal threshold and fails
					echo "$baseroot_file" >> removed.txt
					echo "$basename_file's value of $this_files_value is above threshold. It won't be included."
				fi
			else
				echo "$baseroot_file" >> removed.txt
				echo "WARNING: Removal guide exists but can't find $basename_file in it! Skipping..."
			fi
		done
	else
		# no removal guide, so we keep things simple
		echo "No removal guide found, so we'll add all the files we have to the outfile..."
		cat ~{sep=" " files} >> "~{out_filename}"

		# output first lines if we need to
		if [[ "~{output_first_lines}" = "true" ]]
		then
			touch "~{first_lines_out_filename}.txt"
			FILES=(~{sep=" " files})
			for FILE in "${FILES[@]}"
			do
				if [[ "~{strip_first_line_first_char}" = "true" ]]
				then
					firstline=$(head -1 "$FILE")
					echo "${firstline:1}" >> "~{first_lines_out_filename}.txt"
				else
					head -1 "$FILE" >> "~{first_lines_out_filename}.txt"
				fi
			done
		fi
	fi

	if [[ "~{keep_only_unique_lines}" = "true" ]]
	then
		echo "Sorting and removing non-unique lines..."
		touch temp
		sort "~{out_filename}" | uniq -u >> temp
		rm "~{out_filename}"
		mv temp "~{out_filename}"
	fi

	if [[ ! -f "~{out_filename}" ]]
	then
		printf "\n\n\n ========================= "
		echo "ERROR: Could not locate cat'd file. This probably means either: "
		echo "a) nothing passed the removal threshold (remember, it's a lowpass, not a highpass)"
		echo "b) you didn't actually pass any files in, just an empty array"
		echo "It looks like you tried to merge ~{number_of_files} files."
		if [[ -f removed.txt ]]
		then
			echo "removal.txt doesn't seem to exist, so this looks like option B."
			echo "This task will now exit with an error."
			return 1
		else
			echo "$(number_of_removed_files) files were removed for being below the threshold, or not having removal candidate data."
			echo "The contents of removal.txt will be printed below and this task will then exit with an error."
			cat removed.txt
			return 1
		fi
	fi

	if [[ -f removed.txt ]]
	then
		# count how many samples were removed
		# wc acts differently on different OS, this is most portable way I've found
		number_of_removed_files="$(wc -l removed.txt | awk '{print $1}')"
		echo "$number_of_removed_files" >> number_of_removed_files.txt
	else
		# no samples were removed
		# make sure removed.txt and number_of_removed_files.txt exist so WDL doesn't crash
		touch removed.txt
		number_of_removed_files=0
		echo "$number_of_removed_files" >> number_of_removed_files.txt
	fi
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		File outfile = "~{out_filename}"
		Int files_removed = read_int("number_of_removed_files.txt")
		Int files_input = number_of_files
		Int files_passed = number_of_files - read_int("number_of_removed_files.txt")
		Array[String] removed_files = read_lines("removed.txt")
		File? first_lines = first_lines_out_filename +".txt"
		File? removal_guide = "removal_guide.tsv"
	}
}

task compare_files {
	# NOTE: This modifies an input file
	input {
		File query_file
		File pull_report
	}

	command <<<
	python3 << CODE
	import re
	from difflib import Differ
	pull_sample_minues_status = []
	with open("~{pull_report}", "r") as pull_file_read:
		for line in pull_file_read.readlines():
			subbed=re.sub(": .*", "", line)
			print(f"changing {line} to {subbed}")
			pull_sample_minues_status.append(subbed)
	with open("~{pull_report}", "w") as pull_file_write:
		pull_file_write.writelines(pull_sample_minues_status)
	with open("~{query_file}", "r") as query_file, open("~{pull_report}", "r") as pull_file:
		differ = Differ()
		with open("difference.txt", "w") as difference:
			for line in differ.compare(query_file.readlines(), pull_file.readlines()):
				difference.write(line)
	CODE
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + 10 + " HDD"
		docker: "ashedpotatoes/sranwrp:1.1.8"
		memory: "8 GB"
		preemptible: 2
	}

	output {
		File difference = "difference.txt"
	}
}


## This task removes invalid output from pull_from_SRA_accession.
## Array[Array[File]?] will return empty subarrays sometimes, such
## as with SRR11947402. We can handle that in later tasks, but why
## keep creating garbage instances of a scattered task when we can
## just call a single task to generate known output for us?
## Note: This relies on file-->string-->file coercion working...
#task take_names {
#	input {
#		Array[Array[File]] all_fastqs
#		Array[String] sra_accessions
#
#		Int disk_size = 50
#		Int preempt = 1
#	}
#
#	command <<<
#	python << CODE
#	print('~{sep="," sra_accessions}')
#	print('~{sep="," all_fastqs}')
#	CODE
#	>>>
#
#	runtime {
#		cpu: 4
#		disks: "local-disk " + disk_size + " SSD"
#		docker: "ashedpotatoes/sranwrp:1.0.8"
#		memory: "8 GB"
#		preemptible: preempt
#	}
#
#	#output {
#		#Array[Array[String]] good_fastqs
#		#Array[String] good_accessions
#	#}
#}
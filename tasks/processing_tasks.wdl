version 1.0

# These are tasks that synergize with the other tasks in this repo, but do not
# query SRA (or any other NCBI platform) directly.

task gather_files {
	# A final task for workflows with a lot of outputs across a lot of tasks
	# Useful for forcing miniwdl to put your outputs in a single folder
	input {
		Array[File] some_files
	}
	command <<<
	FILES=( ~{sep=' ' some_files} )
	for FILE in "${FILES[@]}"
	do
		mv "$FILE" .
	done
	>>>
	output {
		Array[File] the_same_files = glob("*")
	}
}

task write_csv {
	input {
		Array[String] headings
		Array[Array[String]] stuff_to_write
		Int lines_of_data = length(stuff_to_write)
		String outfile = "reports.csv"
		Boolean tsv = false
	}

	command <<<
	set -eux -o pipefail
	python << CODE
	
	sep="\t" if "~{tsv}" == "true" else ","
	
	def write_array(array)
		with open("~{outfile}", "a") as f:
			f.write(thing+sep for thing in array)
	
	write_array(["~{sep='","' headings}"])
	if ~{lines_of_data} == 1:
		write_array(["~{sep='","' stuff_to_write}[0]"])
	else:
		pass

	CODE
	>>>

	output {
		File finalOut = outfile
	}

	runtime {
		disks: "local-disk 10 HDD"
		docker: "python:3.12-slim"
		preemptible: 2
		memory: "8 GB"
	}
}

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
		Boolean sort_and_uniq = true
	}
	Int disk_size = ceil(size(accessions_file, "GB")) * 2

	command <<<
	if [[ "~{sort_and_uniq}" = "true" ]]
	then
		sort "~{accessions_file}" | uniq -u > likely_valid.txt
	else
		cp "~{accessions_file}" ./likely_valid.txt
	fi
	python3 << CODE
	import os
	f = open("likely_valid.txt", "r")
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

task extract_accessions_from_file_or_string {
	# Either:
	#  - extract accessions from file as per extract_accessions_from_file
	#  - just pass the string along
	# If both are provided, the string array takes priority.
	# This is useful for allowing myco_sra to run on a Terra data table.
	input {
		Array[String]? accessions_array
		File? accessions_file
		Int preempt = 1
		Boolean filter_na = true
		Boolean sort_and_uniq = true
	}
	# if no accessions file, this will return 2 GB
	Int disk_size = ceil(size(accessions_file, "GB")) * 2 + 2

	command <<<

	if [[ ! "~{sep=' ' accessions_array}" = "" ]]
	then
		ACCESSIONSARRAY=(~{sep=' ' accessions_array})
		printf "%s\n" "${ACCESSIONSARRAY[@]}" > likely_valid.txt
	else
		if [[ "~{accessions_file}" == "" ]]
		then
			echo "Neither accessions array nor accessions file provided!"
			exit 1
		fi
		cp "~{accessions_file}" likely_valid.txt
	fi

	if [[ "~{sort_and_uniq}" = "true" ]]
	then
		sort likely_valid.txt | uniq -u > likely_valid_sorted.txt
		rm likely_valid.txt
		mv likely_valid_sorted.txt likely_valid.txt
	fi

	echo "Currently under consideration:"
	cat likely_valid.txt
	
	# I refuse to do this in bash
	python3 << CODE
	import os
	valid = []
	with open("likely_valid.txt", "r") as f:
		for line in (f.readlines()):
			if line == "":
				pass
			elif line == "NA" and "~{filter_na}" == "true":
				#print("WARNING -- NA found")
				pass
			else:
				split = line.split("\t")
				for accession in split:
					valid.append(accession.strip("\n")+"\n")
	os.system("touch valid.txt")
	with open("valid.txt", "a") as g:
		g.writelines(valid)
	CODE

	echo "Returning:"
	cat valid.txt
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

task strings_to_csv {
	# If you are building a metadata CSV from a Terra data table that has some null values,
	# this should do the trick. If it has no nulls a Map[] would probably be a better option.
	input {
		Array[String] entity_ids
		String        a_metadata_key
		Array[String] a_metadata_values
		String        b_metadata_key
		Array[String] b_metadata_values
	}
	
	command <<<
	python3 << CODE
	import polars as pl

	entity_ids = ['~{sep="','" entity_ids}']
	a_metadata_values = ['~{sep="','" a_metadata_values}']
	b_metadata_values = ['~{sep="','" b_metadata_values}']

	print(a_metadata_values)
	print(b_metadata_values)

	keys = ["entity_id", "~{a_metadata_key}", "~{b_metadata_key}"]
	values = [entity_ids, a_metadata_values, b_metadata_values]
	assert len(keys) == len(values), f"len(keys)={len(keys)} != len(values)={len(values)}"

	lengths = [len(lst) for lst in values]

	max_len = lengths[0]
	assert all(l <= max_len for l in lengths), "One or more metadata lists has more values that there are entity IDs"

	passing_keys, passing_values = [], []
	for key, lst in zip(keys, values):
		if len(lst) == max_len:
			print(f"{key}: {len(lst)} values")
			passing_keys.append(key)
			passing_values.append(lst)
		else:
			print(f"{key} has {len(lst)} values but we expect {max_len}")
	
	# passing_keys is a flat list
	# passing_values is a list of lists
	padded = {
		key: lst
		for key, lst in zip(passing_keys, passing_values)
	}
	print(padded)
	df = pl.DataFrame(padded)
	print(df)
	df.write_csv("metadata_filtered.csv")
	CODE
	>>>

	runtime {
		cpu: 4
		disks: "local-disk 10 HDD"
		docker: "ashedpotatoes/sranwrp:1.1.27"
		memory: "8 GB"
		preemptible: 1
		retries: 1
	}

	output {
		File csv = "metadata_filtered.csv"
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
	# Files going into new_files_quality_reports should be formatted as TSVs
	# where the first column is the filename and the second column is
	# a float value. (Other columns will be ignored.) These TSVs will
	# be cat to create a single big TSV. Then, any values ABOVE the
	# user-input float quality_report_removal_threshold will have their associated
	# file removed, preventing it from being cat'd. In other words,
	# this is a lowpass filter.
	#
	# For example:
	# files = [SAMEA10030079.diff, SAMEA7555065.diff]
	# new_files_quality_reports = [SAMEA10030079.report, SAMEA7555065.report]
	# quality_report_removal_threshold = 0.02
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
	# the quality_report_removal_threshold of 0.02, so it deletes the SAMEA10030079.diff
	# input. As a result, the final cat file will only consist of
	# SAMEA7555065.diff.

	input {
		Array[File] new_files_to_concat
		Array[File]? new_files_quality_reports
		Array[String]? new_files_override_sample_names
		Array[String]? new_files_add_tail_to_sample_names # typically date stamps
		File? king_file               # an already concatenated file you want to concatenate to
		File? king_file_sample_names  # the already concatenated file's sample IDs
		# note: king_file_sample_names is not affected by new_files_override_sample_names nor new_files_add_tail_to_sample_names)
		
		String  out_sample_names = "firstlines.txt"
		Boolean keep_only_unique_files = false       # Tree Nine sets this to true
		Boolean keep_only_unique_lines = false       # may not interact well with other options
		Int     preempt = 1
		String  out_concat_file = "all.txt"
		Float   quality_report_removal_threshold = 0.05
		Boolean sample_name_skips_first_character_on_each_first_line = true
		Boolean verbose = false
		Int?    disk_size_override
		Boolean keep_only_unique_files_ignores_changed_sample_names = false

		Boolean and_then_exit_1 = false              # for quick testing on Terra

		Boolean datestamp_main_files = false
	}
	Int disk_size = select_first([disk_size_override, ceil(size(new_files_to_concat, "GB")) * 2])
	Int number_of_new_files = length(new_files_to_concat)
	Boolean yes_overwrite_sample_names = defined(new_files_override_sample_names)
	Boolean yes_add_datestamps = defined(new_files_add_tail_to_sample_names)

	command <<<
	
	# check for valid inputs
	FILES=(~{sep=" " new_files_to_concat})
	REPORTS=(~{sep= " " new_files_quality_reports})
	OVERWRITES=(~{sep= " " new_files_override_sample_names})
	DATESTAMPS=(~{sep= " " new_files_add_tail_to_sample_names})
	
	if (( ${#REPORTS[@]} != 0 )) && (( ${#REPORTS[@]} != ${#FILES[@]} )); then echo "WARNING: Number of removal guides (${#REPORTS[@]}) doesn't match number of input new_files_to_concat (${#FILES[@]})"; fi
	if (( ${#OVERWRITES[@]} != 0 )) && (( ${#OVERWRITES[@]} != ${#FILES[@]} )); then echo "ERROR: Rename array (${#OVERWRITES[@]}) doesn't match number of input new_files_to_concat (${#FILES[@]})" && exit 1; fi
	if (( ${#DATESTAMPS[@]} != 0 )) && (( ${#DATESTAMPS[@]} != ${#FILES[@]} )); then echo "ERROR: Concat array (${#DATESTAMPS[@]}) doesn't match number of input new_files_to_concat (${#FILES[@]})" && exit 1; fi

	# generate SAMPLE_NAMES (remember: this DOES NOT APPLY to kingfile sample names)
	SAMPLE_NAMES=()
	for i in "${!FILES[@]}"; do
		if [[ "~{yes_overwrite_sample_names}" = "true" ]]; then
			name="${OVERWRITES[$i]}"
		else
			# take first line from file to derive sample name
			firstline=$(head -1 "${FILES[$i]}")
			if [[ "~{sample_name_skips_first_character_on_each_first_line}" = "true" ]]; then
				name="${firstline:1}"
			else
				name="$firstline"
			fi
		fi

		if [[ "~{yes_add_datestamps}" = "true" ]]; then
			name="${name}_${DATESTAMPS[$i]}"
		fi
		SAMPLE_NAMES+=("$name")
	done

	FILES_INPUT_LEN=${#FILES[@]}
	SAMPLE_NAMES_LEN=${#SAMPLE_NAMES[@]}

	echo "---------- Files input in this batch ----------"
	echo "$FILES_INPUT_LEN files input"
	printf "%s\n" "${FILES[@]}"
	echo "---------- Sample names of said input (after processing overwrites and datestamps, excludes anything in kingfile) ----------"
	echo "$SAMPLE_NAMES_LEN sample names"
	printf "%s\n" "${SAMPLE_NAMES[@]}"

	# double check -- should never happen since we already did a similar check earlier, but I don't trust myself writing bash
	if (( FILES_INPUT_LEN != SAMPLE_NAMES_LEN )); then echo "ERROR: Different number of files ($FILES_INPUT_LEN}) doesn't match number of sample names ($SAMPLE_NAMES_LEN), which should never happen this late, so please report it!" && exit 1; fi 

	# now we gotta rename stuff
	if [[ "~{keep_only_unique_files_ignores_changed_sample_names}" = "false" ]]
	then
		RENAMED_FILES=()
		ITER=0
		for FILE in "${FILES[@]}"
		do
			dirname=$(dirname "$FILE")
			ext="${FILE##*.}"

			# new name = same directory + new sample name + original extension
			newfile="${dirname}/${SAMPLE_NAMES[$ITER]}.${ext}"
			mv "$FILE" "$newfile"

			RENAMED_FILES+=("$newfile")
			(( ITER++ ))
		done

		FILES=("${RENAMED_FILES[@]}")
	fi

	if [[ "~{keep_only_unique_files}" = "true" ]]
	then
		# deduplicate FILES by basename (since WDL localization can put input files that share a basename into different folders)
		mapfile -t FILES < <(printf "%s\n" "${FILES[@]}" | awk -F'/' '{if (seen[$NF]++) print "Duplicate basename in FILES:", $0 > "/dev/stderr"; else print}' )
		FILES_DEDUP_LEN=${#FILES[@]}
		printf "\n%s files input, %s remain after internal deduplication" "$FILES_INPUT_LEN" "$FILES_DEDUP_LEN"

		# deduplicate king_file_sample_names, which is an index of files in a file called king_file (which isn't part of FILES)
		# due to how WDL works, this next line checks if king_file_sample_names exists or not -- it's an optional input so it may not!
		if [[ ! "~{king_file_sample_names}" = "" ]]
		then
			mapfile -t KINGFILES < "~{king_file_sample_names}"
			KINGFILES_INPUT_LEN=${#KINGFILES[@]}
			mapfile -t KINGFILES < <(printf "%s\n" "${KINGFILES[@]}" | awk '{if (seen[$0]++) print "Duplicate sample ID in KINGFILES:", $0 > "/dev/stderr"; else print}' )
			KINGFILES_DEDUP_LEN=${#KINGFILES[@]}
			printf "\n%s KINGFILES input, %s remain after internal deduplication" "$KINGFILES_INPUT_LEN" "$KINGFILES_DEDUP_LEN"

			# Remove any FILES that share a sample ID with KINGFILES
			declare -A KING_SAMPLES
			for k in "${KINGFILES[@]}"; do
				KING_SAMPLES["$k"]=1
			done

			FILES_FILTERED=()
			SAMPLE_NAMES_FILTERED=()
			for i in "${!FILES[@]}"; do
				f="${FILES[$i]}"
				sample_id=$(basename "$f" .diff)
				if [[ -n "${KING_SAMPLES[$sample_id]+x}" ]]; then
					printf "\nDuplicate sample ID in both FILES and KINGFILES: %s" "$sample_id"
					printf "\nDuplicate sample ID in both FILES and KINGFILES: %s" "$sample_id" >&2
				else
					FILES_FILTERED+=("$f")
					SAMPLE_NAMES_FILTERED+=("${SAMPLE_NAMES[$i]}")
				fi
			done

			# the actual deduplication
			FILES=("${FILES_FILTERED[@]}")
			SAMPLE_NAMES=("${SAMPLE_NAMES_FILTERED[@]}")

			FILES_DEDUP_LEN=${#FILES[@]}
			printf "\nInput files reduced to %s after removing duplicates against KINGFILES" "$FILES_DEDUP_LEN"

			echo "---------- Files going into tree and stuff (so far) ----------"
			printf "%s\n" "${FILES[@]}"
			if [ ${#FILES[@]} -eq 0 ]; then
				echo "Looks like no files are going in! Skipping removal guide (if any) and returning kingfile..."
				mv "~{king_file}" "~{out_concat_file}"
				mv "~{king_file_sample_names}" "~{out_sample_names}"
				number_of_removed_files="$(wc -l removed.txt | awk '{print $1}')"
				echo "$number_of_removed_files" >> number_of_removed_files.txt
				return 0
			fi
		fi
	fi
	echo "---------- Files going into tree and stuff ----------"
	printf "%s\n" "${FILES[@]}"

	fx_cat_and_firstlines () {
		# $1 is iteration (index), $2 is file
		ITER=$1
		name="${SAMPLE_NAMES[$ITER]}"
		echo "$name" >> "~{out_sample_names}"
		echo ">$name" >> "~{out_concat_file}"
		tail -n +2 "$2" >> "~{out_concat_file}"

		if [[ "~{verbose}" = "true" ]]; then
			echo "iter=$ITER file=$2 → sample_name=$name"
		fi
	}
	
	if [[ ! "~{sep=' ' new_files_quality_reports}" = "" ]]
	then
		echo "Checking which files ought to not be included..."
		cat ~{sep=" " new_files_quality_reports} >> removal_guide.tsv
		ITER=0
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
				is_bigger=$(echo "$this_files_value>~{quality_report_removal_threshold}" | bc) 
				if [[ $is_bigger == 0 ]]
				then
					# this_files_value is below the removal threshold and passes
					fx_cat_and_firstlines $ITER "$FILE"
					if [[ "~{verbose}" = "true" ]]
					then
						echo "$FILE added."
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
			(( ITER++ ))
		done
	else
		# no removal guide, so we keep things simple
		echo "No removal guide found, so we'll add all the files we have to the outfile..."

		# output first lines
		ITER=0
		for FILE in "${FILES[@]}"
		do
			fx_cat_and_firstlines $ITER "$FILE"
			(( ITER++ ))
		done
	fi

	if [[ "~{keep_only_unique_lines}" = "true" ]]
	then
		echo "Sorting and removing non-unique lines..."
		touch temp
		sort "~{out_concat_file}" | uniq -u >> temp
		rm "~{out_concat_file}"
		mv temp "~{out_concat_file}"
	fi

	if [[ ! -f "~{out_concat_file}" ]]
	then
		printf "\n\n\n ========================= "
		echo "ERROR: Could not locate cat'd file. This probably means either: "
		echo "a) nothing passed the removal threshold (remember, it's a lowpass, not a highpass)"
		echo "b) you didn't actually pass any files in, just an empty array"
		echo "It looks like you tried to merge ~{number_of_new_files} files (+1 if you added a kingfile)."
		if [[ -f removed.txt ]]
		then
			echo "removal.txt doesn't seem to exist, so this looks like option B."
			echo "This task will now exit with an error."
			return 1
		else
			number_of_removed_files="$(wc -l removed.txt | awk '{print $1}')"
			echo "$number_of_removed_files" >> number_of_removed_files.txt
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


	if [[ ! "~{king_file}" = "" ]]
	then
		cat "~{out_concat_file}" "~{king_file}" > temp
		rm "~{out_concat_file}"
		mv temp "~{out_concat_file}"
	fi

	if [[ ! "~{king_file_sample_names}" = "" ]]
	then
		cat "~{out_sample_names}" "~{king_file_sample_names}" > temp
		rm "~{out_sample_names}"
		mv temp "~{out_sample_names}"
	fi


	# workaround for CDPH clustering script
	TODAY=$(date -I)
	echo "$TODAY" >> today.txt

	if [[ "~{datestamp_main_files}" = "true" ]]
	then
		mv "~{out_concat_file}" "~{out_concat_file}""$TODAY"
		if [[ ! "~{king_file_sample_names}" = "" ]]
		then
			mv "~{out_sample_names}" "~{out_sample_names}""$TODAY"
		fi
	fi


	if [[ "~{and_then_exit_1}" = "true" ]]
	then
		echo "All is well, but we're exiting one because you said so."
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
		File outfile = glob("~{out_concat_file}*")[0]
		Int files_removed = read_int("number_of_removed_files.txt")
		Int files_input = number_of_new_files
		Int files_passed = number_of_new_files - read_int("number_of_removed_files.txt")
		Array[String] removed_files = read_lines("removed.txt")
		String today = read_lines("today.txt")[0]  # workaround for the CDPH cluster task
		File? first_lines = glob("~{out_sample_names}*")[0]
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

task map_to_tsv_or_csv {
	input {
		Map[String, String] the_map
		String outfile = "something"
		Array[String] column_names = ["values"] # probably should only ever be one value
		Boolean csv = true
		Boolean ordered = true
		Boolean transpose = true
		Boolean round = true
	}
	
	# TODO: make the values column the name of the sample or something
	
	command <<<
	mv ~{write_map(the_map)} map.tsv
	cat map.tsv
	if [[ "~{ordered}" == "true" ]]
	then
		sort -o map.tsv map.tsv
	fi
	python3 << CODE
	import pandas
	raw = pandas.read_csv("map.tsv", sep='\t', index_col=0, names=["~{sep='' column_names}"])
	raw.fillna("N/A", inplace=True)  # necessary b/c Pandas thinks "NA" is NaN and then leaves a black space in CSV
	
	def round_values(x):
		# will be performed on every member of the "values" column iff round is true
		try:
			rounded = round(float(x), 2)
			if rounded.is_integer():
				return int(x)
			else:
				return rounded
		except ValueError:  # string
			return x
	
	if "~{round}" == "true":
		raw = raw.map(round_values)
	
	if "~{transpose}" == "true":
		transposed = raw.T
		print(transposed)
		if "~{csv}" == "true":
			transposed.to_csv("~{outfile}.csv")
		else:
			transposed.to_csv("~{outfile}.tsv", sep='\t')
	else:
		if "~{csv}" == "true":
			raw.to_csv("~{outfile}.csv")
		else:
			raw.to_csv("~{outfile}.tsv", sep='\t')
	CODE
	
	>>>
	
	runtime {
		cpu: 4
		disks: "local-disk " + 10 + " HDD"
		docker: "ashedpotatoes/sranwrp:1.1.15"
		memory: "8 GB"
		preemptible: 2
	}

	output {
		File tsv_or_csv = glob(outfile+"*")[0]
		File? debug_map = "map.tsv"
	}
}

task several_arrays_to_tsv {
	input {
		Array[String] row_keys
		Array[String] column_keys
		Array[Float] value1
		Array[Float] value2
		Array[Int] value3
		Array[Float] value4
		Array[Float] value5
		Array[Float] value6
		Array[Float] value7
		Array[Int] value8
		Array[Int] value9
		Array[Int] value10
		Array[Int] value11
		Array[String] value12
		Array[String] value13
		String output_filename = "qc_report.tsv"
	}

	command <<<
	VALUE12_WITH_SPACES="~{sep='~' value12}"  # yes, we are delimiting with a tilde
	VALUE13_WITH_SPACES="~{sep='~' value13}"

	# shellcheck disable=SC2001
	VALUE12_NO_WHITESPACE=$(echo "$VALUE12_WITH_SPACES" | sed 's/[[:space:]]/_/g')
	# shellcheck disable=SC2001
	VALUE12_NO_COMMAS_NOR_WHITESPACE=$(echo "$VALUE12_NO_WHITESPACE" | sed 's/,//g')
	IFS="~" read -r -a VALUE12_FIXED <<< "$VALUE12_NO_COMMAS_NOR_WHITESPACE"
	# shellcheck disable=SC2001
	VALUE13_NO_WHITESPACE=$(echo "$VALUE13_WITH_SPACES" | sed 's/[[:space:]]/_/g')
	# shellcheck disable=SC2001
	VALUE13_NO_COMMAS_NOR_WHITESPACE=$(echo "$VALUE13_NO_WHITESPACE" | sed 's/,//g')
	IFS="~" read -r -a VALUE13_FIXED <<< "$VALUE13_NO_COMMAS_NOR_WHITESPACE"

	# verbose debugging stuff
	echo "Converted ''$VALUE13_WITH_SPACES'' --> ''$VALUE13_NO_WHITESPACE'' --> ''$VALUE13_NO_COMMAS_NOR_WHITESPACE'' "
	declare -p VALUE12_FIXED
	declare -p VALUE13_FIXED

	ROWS=( ~{sep=' ' row_keys} )
	COLUMNS=( ~{sep=' ' column_keys} )
	VALUE1=( ~{sep=' ' value1} )
	VALUE2=( ~{sep=' ' value2} )
	VALUE3=( ~{sep=' ' value3} )
	VALUE4=( ~{sep=' ' value4} )
	VALUE5=( ~{sep=' ' value5} )
	VALUE6=( ~{sep=' ' value6} )
	VALUE7=( ~{sep=' ' value7} )
	VALUE8=( ~{sep=' ' value8} )
	VALUE9=( ~{sep=' ' value9} )
	VALUE10=( ~{sep=' ' value10} )
	VALUE11=( ~{sep=' ' value11} )

	TARGET_LENGTH=${#ROWS[@]}
	NUMBER_OF_COLUMN_HEADERS=${#COLUMNS[@]}
	EVERYTHING_ELSE=("ROWS" "VALUE1" "VALUE2" "VALUE3" "VALUE4" "VALUE5" "VALUE6" "VALUE7" "VALUE8" "VALUE9" "VALUE10" "VALUE11" "VALUE12_FIXED" "VALUE13_FIXED")

	# shellcheck disable=SC2086
	if [ ${#EVERYTHING_ELSE[@]} -ne $NUMBER_OF_COLUMN_HEADERS ]
	then
		echo "Number of columns (${#EVERYTHING_ELSE[@]}) doesn't match number of column headers ($NUMBER_OF_COLUMN_HEADERS)"
		exit 1
	fi

	for array_name in "${EVERYTHING_ELSE[@]}"
	do
		declare -n array="$array_name"  # nameref the actual array, requires bash > 4.3
		if [ ${#array[@]} -ne "$TARGET_LENGTH" ]
		then
			printf "%s" "ERROR: $array_name has length ${#array[@]} but our target length is $TARGET_LENGTH"
			exit 1
		fi
	done

	for ((i=0; i<NUMBER_OF_COLUMN_HEADERS; i++))
	do
		# this will leave a trailing tab but I think we can live with that
		echo -e -n "${COLUMNS[i]}\t" >> "~{output_filename}"
	done

	# psych! we can't live with a trailing tab! it bothers me too much!
	truncate -s-1 "~{output_filename}" && echo >> "~{output_filename}"

	for ((i=0; i<TARGET_LENGTH; i++))
	do
		echo -e "${ROWS[i]}\t${VALUE1[i]}\t${VALUE2[i]}\t${VALUE3[i]}\t${VALUE4[i]}\t${VALUE5[i]}\t${VALUE6[i]}\t${VALUE7[i]}\t${VALUE8[i]}\t${VALUE9[i]}\t${VALUE10[i]}\t${VALUE11[i]}\t${VALUE12_FIXED[i]}\t${VALUE13_FIXED[i]}" >> "~{output_filename}"
	done

	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + 10 + " HDD"
		docker: "ashedpotatoes/sranwrp:1.1.15"
		memory: "8 GB"
		preemptible: 2
	}

	output {
		File tsv = output_filename
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

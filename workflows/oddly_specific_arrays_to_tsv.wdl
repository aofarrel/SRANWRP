version 1.0

workflow Arrays_to_TSV {
	input {
		Array[String] row_keys = ["SAMEA1101766", "SAMEA1101767"]
		Array[String] column_keys = ["BioSample","raw_pct_above_q20","raw_pct_above_q30","raw_total_reads","post_cleaning_pct_above_q20","post_cleaning_pct_above_q30","post_decontam_pct_above_q20","post_decontam_pct_above_q30","post_decontam_total_reads","reads_bacteria","reads_human","reads_NTM","docker","status"]
		Array[Float] value1 = [0.90, 0.95]
		Array[Float] value2 = [0.80, 0.81]
		Array[Int] value3 = [123, 456]
		Array[Float] value4 = [0.91, 0.99]
		Array[Float] value5 = [0.82, 0.83]
		Array[Float] value6 = [0.92, 1.00]
		Array[Float] value7 = [0.91, 0.99]
		Array[Int] value8 = [12, 45]
		Array[Int] value9 = [1, 4]
		Array[Int] value10 = [100, 5]
		Array[Int] value11 = [2, 88]
		Array[String] value12 = ["ashedpotatoes/nonexistent_docker_image:latest", "ashedpotatoes/nonexistent_docker_image:latest"]
		Array[String] value13 = ["FAIL - foo, but also bar", "PASS"]
	}

	call several_arrays_to_tsv {
		input:
			row_keys = row_keys,
			column_keys = column_keys,
			value1 = value1,
			value2 = value2,
			value3 = value3,
			value4 = value4,
			value5 = value5,
			value6 = value6,
			value7 = value7,
			value8 = value8,
			value9 = value9,
			value10 = value10,
			value11 = value11,
			value12 = value12,
			value13 = value13
	}

	output {
		File check_this_tsv = several_arrays_to_tsv.tsv
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

	VALUE12_NO_WHITESPACE=$(echo "$VALUE12_WITH_SPACES" | sed 's/[[:space:]]/_/g')
	VALUE12_NO_COMMAS_NOR_WHITESPACE=$(echo "$VALUE12_NO_WHITESPACE" | sed 's/,//g')
	IFS="~" read -r -a VALUE12_FIXED <<< "$VALUE12_NO_COMMAS_NOR_WHITESPACE"

	VALUE13_NO_WHITESPACE=$(echo "$VALUE13_WITH_SPACES" | sed 's/[[:space:]]/_/g')
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

	echo "${COLUMNS[@]}" >> "~{output_filename}"

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
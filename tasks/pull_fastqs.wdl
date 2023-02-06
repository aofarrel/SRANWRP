version 1.0

task pull_fq_from_SRA_accession {
	input {
		String sra_accession

		Boolean fail_on_invalid = false
		Int disk_size = 100
		Int preempt = 1
	}

	command <<<
		set -eux pipefail
		prefetch "~{sra_accession}"  # prefetch is not always required, but is good practice
		fasterq-dump "~{sra_accession}"
		NUMBER_OF_FQ=$(fdfind "$SRR" | wc -l)
		echo $NUMBER_OF_FQ > number_of_reads.txt
		IS_ODD=$(echo "$NUMBER_OF_FQ % 2" | bc)
		if [[ $IS_ODD == 0 ]]
		then
			echo "Even number of fastqs"
			echo "~{sra_accession}" > accession.txt
		else
			echo "Odd number of fastqs; checking if we can still use them..."
			if [[ $NUMBER_OF_FQ == 1 ]]
			then
				echo "Only one fastq found"
				if [ "~{fail_on_invalid}" == "true" ]
				then
					exit 1
				else
					# don't fail, but give no output
					rm ./*.fastq
					exit 0
				fi
			else
				if [[ $NUMBER_OF_FQ != 3 ]]
				then
					# somehow we got 5, 7, 9, etc reads
					# this should probably never happen
					echo "Odd number > 3 files found"
					if [ "~{fail_on_invalid}" == "true" ]
					then
						exit 1
					else
						# could probably adapt the 3-case
						rm ./*.fastq
						exit 0
					fi

				fi

				# three files present
				READ1=$(fdfind _1)
				READ2=$(fdfind _2)
				mkdir temp
				mv "$READ1" "temp/$READ1"
				mv "$READ2" "temp/$READ2"
				BARCODE=$(fdfind ".fastq")
				rm "$BARCODE"
				mv "temp/$READ1" "./$READ1"
				mv "temp/$READ2" "./$READ2"
				echo "~{sra_accession}" > accession.txt
			fi
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
		Array[File?] fastqs = glob("*.fastq")
		Int num_fastqs = read_int("number_of_reads.txt")
	}
}

task pull_fq_from_biosample {
	input {
		String biosample_accession

		Boolean fail_on_invalid = false
		Boolean tar_outputs = false
		Int subsample_cutoff = 450
		Int subsample_seed = 1965

		Int disk_size = 100
		Int preempt = 1
	}

	parameter_meta {
    	biosample_accession: "BioSample accession to pull fastqs from"
    	disk_size:           "Size, in GB, of disk (acts as a limit on GCP)"
    	fail_on_invalid:     "Error (instead of exit 0 with null output) if output invalid"
    	preempt:             "Number of times to attempt task on a preemptible VM (GCP only)"
    	subsample_cutoff:    "If fastq > this value in MB, the fastq will be subsampled"
    	subsample_seed:      "Seed to use when subsampling large fastqs"
    	tar_outputs:         "Tarball all fastqs into one output file"
	}

	command <<<
		set -eux pipefail

		echo "~{biosample_accession}" >> ~{biosample_accession}_pull_results.txt
		
		# 1. get SRA accessions from biosample
		SRRS_STR=$(esearch -db biosample -query ~{biosample_accession} | \
			elink -target sra | efetch -format docsum | \
			xtract -pattern DocumentSummary -element Run@acc)

		SRRS_ARRAY=($SRRS_STR)

		# 2. loop through every SRA accession and pull the fastqs
		# TODO: This loop doesn't work as expected. It's sending the whole array.
		# fasterq-dump and prefetch can handle that, but it likely messes up the
		# file check.
		for SRR in "${SRRS_ARRAY[@]}"
		do
			echo "searching $SRR"
			prefetch "$SRR"
			fasterq-dump "$SRR"
			rm -rf "$SRR/"
			NUMBER_OF_FQ=$(fdfind "$SRR" | wc -l)
			IS_ODD=$(echo "$NUMBER_OF_FQ % 2" | bc)
			if [[ $IS_ODD == 0 ]]
			then
				echo "Even number of fastqs"
				
				# check size
				READ1=$(fdfind _1)
				READ2=$(fdfind _2)
				fastq1size=$(du -m "$READ1" | cut -f1)
				if [[ fastq1size -gt ~{subsample_cutoff} ]]
				then
					seqtk sample -s~{subsample_seed} "$READ1" 1000000 > temp1.fq
					seqtk sample -s~{subsample_seed} "$READ2" 1000000 > temp2.fq
					rm "$READ1"
					rm "$READ2"
					mv temp1.fq "$READ1"
					mv temp2.fq "$READ2"
					echo "    $SRR: PASS - downsampled from $fastq1size MB" >> "~{biosample_accession}"_pull_results.txt
				else
					echo "    $SRR: PASS" >> "~{biosample_accession}"_pull_results.txt
				fi


			else
				echo "Odd number of fastqs; checking if we can still use them..."
				if [[ $NUMBER_OF_FQ == 1 ]]
				then
					echo "Only one fastq found"
					echo "    $SRR: FAIL - one fastq" >> "~{biosample_accession}"_pull_results.txt
					if [ "~{fail_on_invalid}" == "true" ]
					then
						exit 1
					else
						# don't fail, but give no output
						rm ./*.fastq
					fi
				else
					if [[ $NUMBER_OF_FQ != 3 ]]
					then
						# somehow we got 5, 7, 9, etc reads
						# this should probably never happen
						echo "Odd number > 3 files found"
						echo "    $SRR: FAIL - odd number > 3 fastqs" >> "~{biosample_accession}"_pull_results.txt
						if [ "~{fail_on_invalid}" == "true" ]
						then
							exit 1
						else
							# could probably adapt the 3-case
							rm ./*.fastq
						fi

					fi

					# three files present
					# do some folder stuff to avoid confusion with other accessions
					mkdir temp
					declare -a THIS_SRA_FQS_ARR
					readarray -t THIS_SRA_FQS_ARR < <(fdfind "$SRR")
					for THING in "${THIS_SRA_FQS_ARR[@]}"
					do
						mv "$THING" "temp/$THING"
					done
					cd temp
					READ1=$(fdfind _1)
					READ2=$(fdfind _2)
					mv "$READ1" "../$READ1"
					mv "$READ2" "../$READ2"
					BARCODE=$(fdfind ".fastq")
					rm "$BARCODE"
					cd ..
					echo "$BARCODE has been deleted, $READ1 and $READ2 remain."

					# check size -- if very large, we should subsample
					fastq1size=$(du -m "$READ1" | cut -f1)
					if (( fastq1size > ~{subsample_cutoff} ))
					then
						seqtk sample -s~{subsample_seed} "$READ1" 1000000 > temp1.fq
						seqtk sample -s~{subsample_seed} "$READ2" 1000000 > temp2.fq
						rm "$READ1"
						rm "$READ2"
						mv temp1.fq "$READ1"
						mv temp2.fq "$READ2"
						echo "    $SRR: PASS - three fastqs and downsampled from $fastq1size MB" >> "~{biosample_accession}"_pull_results.txt
					else
						# not bigger than the cutoff, but still a triplet, so make note of that
						echo "    $SRR: PASS - three fastqs" >> "~{biosample_accession}"_pull_results.txt
					fi
				fi
			fi
		done

		# 3. append biosample name to the fastq filenames
		
		# double check that there actually are fastqs
		NUMBER_OF_FQ=$(fdfind ".fastq" | wc -l)
		if [[ ! $NUMBER_OF_FQ == 0 ]]
		then
			for fq in *.fastq
				do
					mv -- "$fq" "~{biosample_accession}_${fq%.fastq}.fastq"
				done

			# 4. tar the outputs, if that's what you want
			if [ ~{tar_outputs} == "true" ]
			then
				FQ=$(fdfind ".fastq")
				tar -rf "~{biosample_accession}.tar" "$FQ"
			fi
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
		Array[File?] fastqs = glob("*.fastq")
		File? tarball_fastqs = "~{biosample_accession}.tar"
		File results = "~{biosample_accession}_pull_results.txt"
	}
}

# NOTE: This hasn't been throughly tested. It is based on this gist:
# https://gist.github.com/dianalow/5223b77c05b9780c30c633cb255e9fb2
# It doesn't work on DRR or ERR accessions.
task pull_fq_from_bioproject {
	input {
		String bioproject_accession

		Int disk_size = 50
		Int preempt = 1
	}

	command {
		esearch -db sra -query "~{bioproject_accession}" | \
			efetch -format runinfo | \
			cut -d ',' -f 1 | \
			grep SRR | \
			xargs fastq-dump -X 10 --split-files
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[File] fastqs = glob("*.fastq")
	}
}

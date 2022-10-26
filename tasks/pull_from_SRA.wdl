version 1.0

# prefetch is not always required, but is good practice
task pull_from_SRA_directly {
	input {
		String sra_accession

		Boolean fail_on_invalid = false
		Int disk_size = 50
		Int preempt = 1
	}

	command <<<
		set -eux pipefail
		prefetch ~{sra_accession}
		fasterq-dump ~{sra_accession}
		NUMBER_OF_FQ=$(ls -dq *fastq* | wc -l)
		echo $NUMBER_OF_FQ > number_of_reads.txt
		if [ `expr $NUMBER_OF_FQ % 2` == 0 ]
		then
			echo "Even number of fastqs"
			echo "~{sra_accession}" > accession.txt
		else
			echo "Odd number of fastqs; checking if we can still use them..."
			if [ `expr $NUMBER_OF_FQ` == 1 ]
			then
				echo "Only one fastq found"
				if [ ~{fail_on_invalid} == "true" ]
				then
					exit 1
				else
					# don't fail, but give no output
					rm *.fastq
					echo "" > accession.txt
					exit 0
				fi
			else
				if [ `expr $NUMBER_OF_FQ` != 3 ]
				then
					# somehow we got 5, 7, 9, etc reads
					# this should probably never happen
					echo "Odd number > 3 files found"
					if [ ~{fail_on_invalid} == "true" ]
					then
						exit 1
					else
						# could probably adapt the 3-case
						rm *.fastq
						echo "" > accession.txt
						exit 0
					fi

				fi

				# three files present
				READ1=$(ls -dq *_1*)
				READ2=$(ls -dq *_2*)
				mkdir temp
				mv $READ1 temp/$READ1
				mv $READ2 temp/$READ2
				BARCODE=$(ls -dq *fastq*)
				rm $BARCODE
				mv temp/$READ1 ./$READ1
				mv temp/$READ2 ./$READ2
				echo "~{sra_accession}" > accession.txt
			fi
		fi
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.5"
		memory: 8
		preemptible: preempt
	}

	output {
		Array[File]? fastqs = glob("*.fastq")
		String sra_accession_out = read_string("accession.txt")
		Int num_fastqs = read_int("number_of_reads.txt")
	}
}

# This task removes invalid output from pull_from_SRA_directly.
# Array[Array[File]?] will return empty subarrays sometimes, such
# as with SRR11947402. We can handle that in later tasks, but why
# keep creating garbage instances of a scattered task when we can
# just call a single task to generate known output for us?
# Note: This relies on file-->string-->file coercion working...
task take_names {
	input {
		Array[Array[String]] all_fastqs
		Array[String] sra_accessions

		Int disk_size = 50
		Int preempt = 1
	}

	command <<<
	python3 CODE <<
	print('~sep="," sra_accessions')
	print('~{sep="," all_fastqs}')
	CODE
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.5"
		memory: 8
		preemptible: preempt
	}

	#output {
		#Array[Array[String]] good_fastqs
		#Array[String] good_accessions
	#}
}

# NOTE: This hasn't been throughly tested. It is based on this gist:
# https://gist.github.com/dianalow/5223b77c05b9780c30c633cb255e9fb2
task pull_from_SRA_by_bioproject {
	input {
		String bioproject_accession

		Int? disk_size = 50
		Int? preempt = 1
	}

	command {
		esearch -db sra -query ~{bioproject_accession} | \
			efetch -format runinfo | \
			cut -d ',' -f 1 | \
			grep SRR | \
			xargs fastq-dump -X 10 --split-files
	}

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.4"
		memory: 8
		preemptible: preempt
	}

	output {
		Array[File] fastqs = glob("*.fastq")
	}
}
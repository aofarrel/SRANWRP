version 1.0

task pull_fq_from_SRA_accession {
	input {
		String sra_accession

		Boolean fail_on_invalid = false
		Int disk_size = 50
		Int preempt = 1
	}

	command <<<
		set -eux pipefail
		prefetch ~{sra_accession}  # prefetch is not always required, but is good practice
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
					#touch DONOTUSE.fastq
					#echo "" > accession.txt
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
						#touch DONOTUSE.fastq
						#echo "" > accession.txt
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
		docker: "ashedpotatoes/sranwrp:1.0.7"
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
		Int disk_size = 50
		Int preempt = 1
	}

	command <<<
		set -eux pipefail



		prefetch ~{sra_accession}  # prefetch is not always required, but is good practice
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
					#touch DONOTUSE.fastq
					#echo "" > accession.txt
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
						#touch DONOTUSE.fastq
						#echo "" > accession.txt
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
		docker: "ashedpotatoes/sranwrp:1.0.7"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[File?] fastqs = glob("*.fastq")
		Int num_fastqs = read_int("number_of_reads.txt")
	}
}

# NOTE: This hasn't been throughly tested. It is based on this gist:
# https://gist.github.com/dianalow/5223b77c05b9780c30c633cb255e9fb2
# It doesn't work on DRR or ERR accessions.
task pull_fq_from_bioproject {
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
		docker: "ashedpotatoes/sranwrp:1.0.7"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[File] fastqs = glob("*.fastq")
	}
}

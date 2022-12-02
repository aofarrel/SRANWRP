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
		docker: "ashedpotatoes/sranwrp:1.0.8"
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

		Boolean tar_outputs = false
		Boolean fail_on_invalid = false
		Int disk_size = 50
		Int preempt = 1
	}

	command <<<
		set -eux pipefail

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
			prefetch $SRR
			fasterq-dump $SRR
			NUMBER_OF_FQ=$(ls -dqp $SRR* | grep -v / | wc -l)
			if [ `expr $NUMBER_OF_FQ % 2` == 0 ]
			then
				echo "Even number of fastqs"
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
							exit 0
						fi

					fi

					# three files present
					# do some folder stuff to avoid confusion with other accessions
					mkdir temp
					THIS_SRA_FQS=$(ls -dq *$SRR*)
					THIS_SRA_FQS_ARR=($THIS_SRA_FQS)
					for THING in "${THIS_SRA_FQS_ARR[@]}"
						do mv $THING temp/$THING
					done
					cd temp
					READ1=$(ls -dq *_1*)
					READ2=$(ls -dq *_2*)
					mkdir temptemp
					mv $READ1 temptemp/$READ1
					mv $READ2 temptemp/$READ2
					BARCODE=$(ls -dq *fastq*)
					rm $BARCODE
					cd ..
					mv temp/temptemp/$READ1 ./$READ1
					mv temp/temptemp/$READ2 ./$READ2
				fi
			fi
		done

		# 3. append biosample name to the fastq filenames
		for fq in *.fastq
		do
			mv -- "$fq" "~{biosample_accession}_${fq%.fastq}.fastq"
		done

		# 4. tar the outputs, if that's what you want
		if [ ~{tar_outputs} == "true" ]
		then
			# double check that there actually are fastqs
			NUMBER_OF_FQ=$(ls *.fastq | grep -v / | wc -l)
			if [ `expr $NUMBER_OF_FQ` == 0 ]
			then
				tar -tf ~{biosample_accession}.tar --wildcards '*.fastq'
			fi
		fi
		

	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.0.8"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[File?] fastqs = glob("*.fastq")
		File? tarball_fastqs = glob("*.tar")[0]
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
		docker: "ashedpotatoes/sranwrp:1.0.8"
		memory: "8 GB"
		preemptible: preempt
	}

	output {
		Array[File] fastqs = glob("*.fastq")
	}
}

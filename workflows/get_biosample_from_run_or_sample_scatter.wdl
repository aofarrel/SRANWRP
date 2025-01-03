version 1.0

# Convert run or ENA/DDBJ accessions into BioSample accessions, using scattered tasks but avoiding elink
# Author: Ash O'Farrell

import "../tasks/processing_tasks.wdl" as processingtasks
import "../tasks/get_metadata.wdl" as metatasks

workflow SRA_TO_BIOSAMP {
	input {
		File sra_accessions
		Boolean sort_and_uniq = false
	}

	call processingtasks.extract_accessions_from_file as get_run_IDs {
		input:
			accessions_file = sra_accessions,
			sort_and_uniq = false
	}


	scatter(sra_accession in get_run_IDs.accessions) {
		call metatasks.get_biosample_from_read_or_ENA_without_elink as get_samples {
			input:
				sra_accession = sra_accession
		}
	}

	call processingtasks.cat_files as cat {
		input:
			files = get_samples.accession_as_file,
			keep_only_unique_lines = sort_and_uniq
	}

	output {
		File unique_biosample_accessions = cat.outfile
	}

}
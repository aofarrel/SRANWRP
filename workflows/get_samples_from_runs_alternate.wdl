version 1.0

# Convert run or ENA/DDBJ accessions into Biosample accessions, with neither scattered tasks
# nor elink
# Author: Ash O'Farrell

import "../tasks/processing_tasks.wdl" as processingtasks
import "../tasks/get_metadata.wdl" as metatasks

workflow SRA_TO_BIOSAMP {
	input {
		File sra_accessions
	}

	call processingtasks.extract_accessions_from_file as get_run_IDs {
		input:
			accessions_file = sra_accessions
	}


	call metatasks.get_biosample_from_read_or_ENA_accession_without_elink as get_samples {
		input:
			sra_accessions = get_run_IDs.accessions
	}


	output {
		File unique_biosample_accessions = get_samples.accessions_as_file
	}

}
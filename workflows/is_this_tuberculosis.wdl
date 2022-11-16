version 1.0

import "../tasks/get_metadata.wdl" as metatasks
import "../tasks/processing_tasks.wdl" as processingtasks
#import "https://raw.githubusercontent.com/aofarrel/SRANWRP/bioproject_stuff/tasks/get_metadata.wdl" as metatasks
#import "https://raw.githubusercontent.com/aofarrel/SRANWRP/bioproject_stuff/tasks/processing_tasks.wdl" as processingtasks

# How to use:
# 1. Use NCBI's web search to look for what you want, such as:
# (("bioproject sra"[Filter]) AND ("mycobacterium tuberculosis"[Organism] OR "mycobacterium tuberculosis complex"[Organism]))
# 2. In the drop down menu, select "Send to" > "File" radio > "Accessions list" dropdown > "Create File" button
# 3. Have the resulting file be the input to this pipeline

workflow IS_THIS_TUBERCULOSIS {
	input {
		File bioprojects_file
	}

	call processingtasks.extract_accessions_from_file as get_bioproj_IDs {
		input:
			bioprojects_file = bioprojects_file
	}


	scatter(bioproject_accession in get_bioproj_IDs.bioproject_accessions) {
		call metatasks.get_organism_per_SRA_accession_from_bioproject as get_organism_names {
			input:
				bioproject_accession = bioproject_accession
		}
	}

	call processingtasks.cat_files as cat {
		input:
			files = get_organism_names.organisms_and_SRA_accessions
	}

	output {
		Array[File] all_organism_files = get_organism_names.organisms_and_SRA_accessions # useful if cat takes too long
	}

}
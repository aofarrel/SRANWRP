version 1.0

import "" as sratasks
import "" as processingtasks

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
		call sratasks.get_organism_per_SRA_accession_from_bioproject as get_organism_names {
			input:
				bioproject_accession = bioproject_accession
		}
	}

}
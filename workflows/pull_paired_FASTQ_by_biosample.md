# pull_FASTQs_from_SRA_by_biosample
**This workflow is identical to pull_FASTQs_from_SRA_by_biosample_nofile except that this version takes in a text file of BioSample accessions, and the nofile version directly takes in an array of strings.**

## Important notes
* Any accessions which are not paired Illumina FQs will be skipped. This is intentional.
* Relies on prefetch, which by default will top out at 20000000 KB (20 GB). Adjust this limit via `pull.prefetch_max_size_KB`.
* Generally speaking, `disk_size` needs to be 11x the download size of the largest FASTQ in the set.
* A handful of accessions, while appearing valid on SRA's website, do not properly interact with sra-tools or e-direct and therefore cannot be processed.

## Features
* Downloads that fail will not crash the pipeline (unless you run out of disk space) and the failures will be recorded as part of the "pull report"
    * This makes mass-downloading relatively unknown accessions significantly easier, as the "bad" ones will not stop the entire pipeline
    * You can disable this feature to force a crash to happen if any download fails
* Supports BioSamples with multiple run accessions
* Supports run accessions that have any even number of fastqs
* Supports run accessions that have three fastqs
* Optionally downsample your downloaded fastqs immediately
* Effectively "blocks" non-Illumina data formats (PacBio, etc) that your downstream tooling might not be able to handle
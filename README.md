# SRAnwrp [![DockerHub Link](https://img.shields.io/docker/v/ashedpotatoes/sranwrp/1.1.7?logo=docker)](https://hub.docker.com/r/ashedpotatoes/sranwrp/tags) [![Quay.io Link](https://img.shields.io/badge/quay.io-1.1.7-blue?logo=redhat "Docker Repository on Quay")](https://quay.io/repository/aofarrel/sranwrp)
SRAnwrp ("Saran Wrap") envelops several SRA-related tools in the warm, polyethylene embrace of a single Ubuntu-based Docker image and some optional assorted workflows. For the sake of simplicity, releases on main follow the same versioning scheme as the Docker image.

## What tasks can it perform?
The combination of e-direct and sra-tools allows it do basically anything you can do from SRA's website. These exist in the form of WDL workflows -- [more on WDL here](./wdl.md).

### Pulling FASTQs
* [Pull paired FASTQs from a list of run accessions (SRR/ERR/DRR)](./workflows/pull_paired_FASTQ_by_run_accession.wdl)
* [Pull paired FASTQs from a lit of BioSample accessions - can be SRS or SAME notation](./workflows/pull_paired_FASTQ_by_biosample.wdl)
* Plus some bonus [non-workflow pulling tasks](./tasks/pull_fastqs.wdl)
* *Note* -- as fasterq-dump is being used, pulling non-Illumina fastqs is not supported.

### Getting Organism + TaxID from a list of BioProject/BioSample accessions
There's a lot of BioProjects on SRA, and some of them are multi-species. Use [this workflow](./workflows/get_organisms_from_bioproject.wdl) to get a list of all run accessions, and said run accessions' species and TaxIDs, from a list of BioProject accessions. If you instead have a list of BioSamples, use [this workflow](./workflows/get_organisms_from_biosample.wdl) to get species and taxid (as well as a list of all run accessions).

### Getting sample accessions from run accessions (SRR/ERR/DRR)
If you have a list of run accessions, [this workflow](./workflows/get_samples_from_runs.wdl) will get a list of sample accessions that they cover. Some samples have more than one run -- those samples will only appear in the output once.

### Other stuff?
Here's [some other tasks](./tasks/processing_tasks.wdl) that can help you convert between data types.

## What's included in the Docker image?
Non-exhaustive list:
* bash-5.1.16(1)-release
* [bedtools-latest](https://github.com/arq5x/bedtools2)
* [bc-latest](https://www.gnu.org/software/bc/)
* bcftools-1.16
* cpan-latest
* curl-latest
* [entrez-direct-latest](https://www.ncbi.nlm.nih.gov/books/NBK179288/) (aka edirect)
* gcc-latest
* git-latest
* htslib-1.16
* make-latest
* Matplotlib-latest
* [numpy-latest](https://github.com/numpy/numpy)
* [pandas-latest](https://github.com/pandas-dev/pandas)
* [pigz-latest](https://github.com/madler/pigz)
* python-3.11
	* **note:** must be called with `python3` instead of `python` (and `pip3` instead of `pip`) when running non-interactively
* [samtools-1.16](https://github.com/samtools/samtools) 
  * mpileup, minimap2, fixmate, etc
* [seqtk-latest](https://github.com/lh3/seqtk)
* [sra-tools-3.0.1](https://github.com/ncbi/sra-tools) (aka SRAtools, SRA tools, SRA toolkit, etc)
	* align-info, fastq-dump, fasterq-dump, prefetch, sam-dump, sra-pileup, etc
	* fyi: [ncbi/ncbi-vdb](https://github.com/ncbi/ncbi-vdb) was merged with sra-tools in sra-tools-3.0.0 and vdb-get was retired in 3.0.1
* sudo-latest
* [taxoniumtools-latest](https://github.com/theosanderson/taxonium/tree/master/taxoniumtools)
* tree-latest
* vim-latest
* wget-latest

## Who builds?
Right now, the image is built and pushed manually.

## Why?
* Docker Hub's latest version of staphb/sratoolkit, as of my writing this in October 2022, [runs version 2.9.2 (see command 15)](https://hub.docker.com/layers/staphb/sratoolkit/latest/images/sha256-84fc990e6d04f263d7bea82dcbff7f5dd9182ab5234314bb0daf2e2db977e4a0?context=explore), which [doesn't work at all anymore](https://github.com/ncbi/sra-tools/issues/714)
* Existing Docker images tend to contain either the SRA toolkit or Entrez Direct, not both
* Building SRA Toolkit on your own, without conda, is not intuitive
* Building SRA Toolkit on your own, with conda, is also not intutive (you usually end up with v2.10 which [only sometimes works](./debug/README.md))
* No need to run `vdb-config --interactive` or any other interactive process before using anything in this image; SRA Toolkit's config file is generated while building the image

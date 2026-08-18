# SRAnwrp
SRAnwrp ("Saran Wrap") envelops several bioinformatics-related tools in the warm, polyethylene embrace of a single Ubuntu-based Docker image. It additionally serves as a standard library of importable WDL (Workflow Description Language) tasks, some of which are specifically for pulling data from NCBI SRA, but others are more general-purpose. Versioning of the Docker image *and* the WDLs follow versioning of this repo, although in most releases only either the WDLs or the Docker image is updated. 

Several of SRAnwrp's workflows, as well as its Docker image, are used by the *Mycobacterium tuberculosis* processing workflow [myco_sra](https://dockstore.org/workflows/github.com/aofarrel/myco/myco_sra), which was used to build [a massive phylogenetic tree of MTBC](https://www.taxonium.org/tuberculosis/SRA) as described in [this preprint](https://www.medrxiv.org/content/10.1101/2025.07.22.25331806v1). 


## What tasks can it perform?
The combination of e-direct and sra-tools allows it do basically anything you can do from SRA's website. These exist in the form of WDL workflows -- [more on WDL here](./wdl.md).

## Workflows
### Pulling FASTQs
* [Pull paired FASTQs from a list of run accessions (SRR/ERR/DRR)](./workflows/pull_paired_FASTQ_by_run_accession.wdl)
* [Pull paired FASTQs from a lit of BioSample accessions - can be SRS or SAME notation](./workflows/pull_paired_FASTQ_by_biosample.wdl)
* Plus some bonus [non-workflow pulling tasks](./tasks/pull_fastqs.wdl)
* *Note* -- it is recommended you set the disk_size variable to 20x the size of the largest .sra that you want to download.

Note that version 3.0.1 of [sra-tools](https://github.com/ncbi/sra-tools), which is the version used in SRAnwrp, throws an error when pulling non-Ilummina fastqs with the fasterq-dump command. The SRAnwrp WDLs currently rely upon this behavior in order to only download Illumina fastqs, which is an intentional design decision. The *raison d'être* of SRAnwrp's fastq-pulling WDL is to run upstream of [clockwork-wdl](https://github.com/aofarrel/clockwork-wdl) within [myco_sra](https://github.com/aofarrel/myco/blob/main/myco_sra.wdl), and clockwork strictly supports only Illumina. If you update to sra-tools 3.0.5 or later, you will gain support of other sequencing technologies, but the WDLs will break.

### Getting Organism + TaxID from a list of BioProject/BioSample accessions
There's a lot of BioProjects on SRA, and some of them are multi-species. Use [this workflow](./workflows/get_organisms_from_bioproject.wdl) to get a list of all run accessions, and said run accessions' species and TaxIDs, from a list of BioProject accessions. If you instead have a list of BioSamples, use [this workflow](./workflows/get_organisms_from_biosample.wdl) to get species and taxid (as well as a list of all run accessions).

> [!TIP]
> A very small number of BioSamples, such as [SAMEA968096](https://www.ncbi.nlm.nih.gov/sra/?term=SAMEA968096), are in "sample pools." Running fasterq-dump on such samples will return all run accessions for all BioSamples in that sample pool, often including a generic barcode sample. This may cause issues with downstream analysis; such samples should likely be avoided.
> Samples in a sample pool are marked on SRA's UI: <img width="382" height="26" alt="Screenshot 2026-08-06 at 3 21 58 PM" src="https://github.com/user-attachments/assets/2622ba59-3040-4492-a442-4638f83fee8f" />
>
> [A denylist of MTBC samples within sample groups that I'm aware of has been compiled in this repo](https://github.com/aofarrel/SRANWRP/tree/main/inputs/denylists#accessions-within-sample-groups), but there may be more out there.

### Getting sample accessions from run accessions (SRR/ERR/DRR)
If you have a list of run accessions, [this workflow](./workflows/get_samples_from_runs.wdl) will get a list of sample accessions that they cover. Some samples have more than one run -- those samples will only appear in the output once.

### Miscellanous helpful WDL workflows
SRAnwrp also features [several miscellanous WDL tasks](./tasks/processing_tasks.wdl) that can help you convert between data types or perform common WDL tasks.

## Docker Image
* The last version of the SRAnwrp Docker image to be based on Jammy Jellyfish and Python 3.12 was ashedpotatoes/sranwrp:1.2.3
* In attempt to future-proof some WDLs prior to handoff, ashedpotatoes/sranwrp:1.3.0 is built on Resolute Raccoon and uses Python 3.14, but as these are less well-tested, ashedpotatoes/sranwrp:1.2.3 will remain on Docker Hub
* As noted above, SRAnwrp's fastq-pulling WDLs rely on sra-tools 3.0.1 specifically, so that is what is pinned in the Docker image
* Also included: [bedtools](https://github.com/arq5x/bedtools2), [seqtk](https://github.com/lh3/seqtk), [entrez-direct (aka edirect)](https://www.ncbi.nlm.nih.gov/books/NBK179288/), the samtools/bcftools/htslib trinity, [FISS](https://github.com/broadinstitute/fiss), and [Ranchero](https://github.com/aofarrel/ranchero). See the Dockerfile for more information.

### Building
The image is built and pushed manually. If you want to roll your own, you'll need to include your own copy of the TB reference tarball -- it can be created with [clockwork reference_prepare](https://github.com/aofarrel/clockwork-wdl/blob/main/tasks/ref_prep.wdl), or downloaded from `gs://ucsc-pathogen-genomics-public/tb/ref/clockwork-v0.12.5/Ref.H37Rv.tar` (this is a public requester-pays bucket). MD5s are provided in this repo as a double-check.

### Why does this image exist?
At the time this Docker image was first developed in October 2022:
* The latest version of staphb/sratoolkit on Docker Hub [ran version 2.9.2 (see command 15) of sra-tools](https://hub.docker.com/layers/staphb/sratoolkit/latest/images/sha256-84fc990e6d04f263d7bea82dcbff7f5dd9182ab5234314bb0daf2e2db977e4a0?context=explore), which [doesn't work at all anymore](https://github.com/ncbi/sra-tools/issues/714)
* Other existing Docker images tend to contain either the SRA toolkit or Entrez Direct, not both
* Building SRA Toolkit on your own, without conda, was not intuitive
* Building SRA Toolkit on your own, with conda, was also not intuitive (you usually end up with v2.10 which only sometimes works)


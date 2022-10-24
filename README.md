# SRAnwrp ![Docker Image Version (latest by date)](https://img.shields.io/docker/v/ashedpotatoes/sranwrp)
SRAnwrp ("Saran Wrap") envelops several SRA-related tools in the warm, polyethylene embrace of a single Docker image.

## Where?
You can find the Docker image at [ashedpotatoes/sranwrp](https://hub.docker.com/repository/docker/ashedpotatoes/sranwrp).

## What's Included?
Non-exhaustive list:
* bedtools-latest
* bcftools-1.16
* cpan-latest
* curl-latest
* entrez-direct-latest (aka edirect)
* gcc-latest
* htslib-1.16
* make-latest
* pigz-latest
* python-3.10
* samtools-1.16 
* sra-tools-3.0.0 (aka SRAtools, SRA tools, SRA toolkit, etc)
	* align-info, fastq-dump, fasterq-dump, prefetch, sam-dump, sra-pileup, etc
	* Note that [ncbi/ncbi-vdb](https://github.com/ncbi/ncbi-vdb) was merged with sra-tools in sra-tools-3.0.0
* sudo-latest
* tree-latest
* vim-latest
* wget-latest

## Why?
* Docker Hub's latest version of staphb/sratoolkit, as of my writing this in October 2022, [runs version 2.9.2 (see command 15)](https://hub.docker.com/layers/staphb/sratoolkit/latest/images/sha256-84fc990e6d04f263d7bea82dcbff7f5dd9182ab5234314bb0daf2e2db977e4a0?context=explore), which [doesn't work at all anymore](https://github.com/ncbi/sra-tools/issues/714)
* Existing Docker images tend to contain either the SRA toolkit or Entrez Direct, not both
* Building SRA Toolkit on your own, without conda, is not intuitive
* Building SRA Toolkit on your own, with conda, is also not intutive (you usually end up with v2.10 which [only sometimes works](./debug/README.md))
* No need to run `vdb-config --interactive` or any other interactive process before using anything in this image; SRA Toolkit's config file is generated while building the image
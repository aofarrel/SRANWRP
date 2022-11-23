# SRAnwrp [![DockerHub Link](https://img.shields.io/docker/v/ashedpotatoes/sranwrp/1.0.7?logo=docker)](https://hub.docker.com/r/ashedpotatoes/sranwrp/tags) [![Quay.io Link](https://img.shields.io/badge/quay.io-1.0.7-blue?logo=redhat "Docker Repository on Quay")](https://quay.io/repository/aofarrel/sranwrp)
SRAnwrp ("Saran Wrap") envelops several SRA-related tools in the warm, polyethylene embrace of a single Docker image. For the sake of simplicity, releases on main follow the same versioning scheme as the Docker image.

## Where?
You can find the Docker image on Docker Hub as [ashedpotatoes/sranwrp](https://hub.docker.com/r/ashedpotatoes/sranwrp) and Quay.io as [aofarrel/sranwrp](https://quay.io/aofarrel/sranwrp). You can find a WDL task in [tasks/pull_from_SRA.wdl](./tasks/pull_from_SRA.wdl) and a WDL workflow in [workflows/pull_from_SRA_simple.wdl](workflows/pull_from_SRA_simple.wdl).

## WDL?
[More information here.](./wdl.md)

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
* [pigz-latest](https://github.com/madler/pigz)
* python-3.10
	* aliased to python and python3
* [samtools-1.16](https://github.com/samtools/samtools) 
* [sra-tools-3.0.0](https://github.com/ncbi/sra-tools) (aka SRAtools, SRA tools, SRA toolkit, etc)
	* align-info, fastq-dump, fasterq-dump, prefetch, sam-dump, sra-pileup, etc
	* Note that [ncbi/ncbi-vdb](https://github.com/ncbi/ncbi-vdb) was merged with sra-tools in sra-tools-3.0.0
* sudo-latest
* tree-latest
* vim-latest
* wget-latest

## Who Builds?
Right now, the image is built and pushed manually.

## Why?
* Docker Hub's latest version of staphb/sratoolkit, as of my writing this in October 2022, [runs version 2.9.2 (see command 15)](https://hub.docker.com/layers/staphb/sratoolkit/latest/images/sha256-84fc990e6d04f263d7bea82dcbff7f5dd9182ab5234314bb0daf2e2db977e4a0?context=explore), which [doesn't work at all anymore](https://github.com/ncbi/sra-tools/issues/714)
* Existing Docker images tend to contain either the SRA toolkit or Entrez Direct, not both
* Building SRA Toolkit on your own, without conda, is not intuitive
* Building SRA Toolkit on your own, with conda, is also not intutive (you usually end up with v2.10 which [only sometimes works](./debug/README.md))
* No need to run `vdb-config --interactive` or any other interactive process before using anything in this image; SRA Toolkit's config file is generated while building the image

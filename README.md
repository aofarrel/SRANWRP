# SRAnwrp
SRAnwrp ("Saran Wrap") envelops several SRA-related tools in the warm, polyethylene embrace of a single Docker image.

## Where?
* You can find the Docker image at [ashedpotatoes/sranwrp:1.0.1](https://hub.docker.com/repository/docker/ashedpotatoes/sranwrp)

## Why?
* Docker Hub's latest version of staphb/sratoolkit, as of my writing this in October 2022, [runs version 2.9.2 (see command 15)](https://hub.docker.com/layers/staphb/sratoolkit/latest/images/sha256-84fc990e6d04f263d7bea82dcbff7f5dd9182ab5234314bb0daf2e2db977e4a0?context=explore), which [doesn't work anymore](https://github.com/ncbi/sra-tools/issues/714)
* Existing Docker images tend to contain either the SRA toolkit or Entrez Direct, not both
* Installing SRA Toolkit on your own, without conda, is not intuitive


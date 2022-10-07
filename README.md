# SRANWRP

SRANWRP ("Saran Wrap") envelops several SRA-related commands in a warm, polyethylene embrace.


## Why?
* Docker Hub's staphb/sratoolkit:latest, as of October 2022, [runs version 2.9.2 (see command 15)](https://hub.docker.com/layers/staphb/sratoolkit/latest/images/sha256-84fc990e6d04f263d7bea82dcbff7f5dd9182ab5234314bb0daf2e2db977e4a0?context=explore), which [doesn't work anymore](https://github.com/ncbi/sra-tools/issues/714).
* Existing Docker images tend to contain either the SRA toolkit or Entrez Direct, not both.
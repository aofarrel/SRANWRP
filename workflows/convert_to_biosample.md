# get BioSample from SRR, ERR, DRR, SRS, or ERS

Convert any combination of these:
* SRA-style run accessions, like SRR9291314
* ENA-style run accessions, like ERR4810509
* DDBJ-style run accessions, like DRR351781
* SRA-style sample accessions, like SRS4962036
* ENA-style sample accessions, like ERS5298534
* DDBJ-style sample accessions, like DRS365803
* Numerical UIDs, like [394039](https://www.ncbi.nlm.nih.gov/sra/?term=394039) -- these can easily be confused with BioProject UIDs, so it's not recommended to use them

Into a BioSample accession, which typically starts with SAMN, SAME, or SAMD. This is useful for combining datasets that may use different methods for identifying samples.

## scattered or not scattered?
Use the scattered version if:
* You are **not** running this locally on Cromwell on default settings (miniwdl locally is fine; Cromwell specifically can't handle scattered tasks properly)
* You don't want to deal with elink

Use the not-scattered version if:
* You're stuck using Cromwell locally
* elink is in a good mood today
* You do not need your output to be the same order as your input

## example
If you input this text file:
```
SRR9291314
SRR9291315
SRS4962036
ERR4810509
ERS5298534
DRR351781
DRS365803
34
```
You would get this if running `_scatter`, which maintains sample order:
```
SAMN12046450
SAMN12046450
SAMN12046450
SAMEA7542084
SAMEA7542082
SAMD00444260
SAMD00444260
SAMN00000027
```
or this if running `_no_scatter`, which sorts and drops repeated outputs:
```
SAMD00444260
SAMEA7542082
SAMEA7542084
SAMN00000027
SAMN12046450
```


More specifically:
* SRR9291314 --> SAMN12046450
* SRR9291315 --> SAMN12046450
    * SRR9291314 and SRR9291315 are two different run accessions, but are both considered part of BioSample SAMN12046450
* SRS4962036 --> SAMN12046450
* ERR4810509 --> SAMEA7542084
* ERS5298534 --> SAMEA7542082
* DRR351781 --> SAMD00444260
* DRS365803 --> SAMD00444260
* [34](https://www.ncbi.nlm.nih.gov/sra/?term=34) --> SAMN00000027


## features
* Designed to be able to handle the quirks of the text files you can get from NCBI's search feature, which can have odd line breaks or "NA", or files you compile yourself
* Optionally sort and uniq your input file
    * If you choose not to do this, your outputs will be in the exact same order of your inputs, which is handy for batch operations (we used this to convert 12K TB samples into BioSamples)
* Optionally drop anything in a "sample group"/"sample pool", as they can cause issues with certain bioinformatics tools

## notes

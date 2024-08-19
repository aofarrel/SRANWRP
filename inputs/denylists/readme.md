# denylists
A list of denylists of samples known to be problematic when fed through [myco_sra](https://github.com/aofarrel/myco) and/or this repo's pull_fastqs.wdl (specifically the pull_fq_from_biosample task).

In [release 1.1.7](https://github.com/aofarrel/SRANWRP/releases/tag/v1.1.7) and onwards, pull_fq_from_biosample's default behavior is to attempt to exit gracefully (rather than crash the entire WDL pipeline) if a sample is invalid. This prevents the entire WDL pipeline from crashing if a run accession fails to download due to an error in prefetch or fasterq-dump. However, some particularly tricky data still causes problems, so we still need a denylist.

In release 1.1.19, denylists were greatly expanded and reorganized.

# Why deny?

## Doesn't really fit what we're trying to do here
PRJNA706121 is full of synthetic data. While it's great for testing our decontamination pipeline, that data should not be on the final phylogenetic tree.

PRJNA323744 is hundreds of resequences of the same 44 patients, with data taken from various body parts post-mortem. This has implications for decontamination, but is likely to create false clusters on our phylogenetic tree due to so much of the data being near-identical. (We could grab one sample per each of the 44 patients, but it is "safest" to exclude the entire BioProject.)

## QC oddities
Several (not all) samples in PRJNA1011210 have extremely low quality scores for read 2, resulting in those samples being wiped out by fastp. For simplicity we have denylisted the entire BioProject.

## Metadata oddities
Samples in PRJNA897841 appear to be missing metadata on what type of sequencer was used.

## It's just too darn big
SAMN17359332 has [a lot](https://www.ncbi.nlm.nih.gov/sra?LinkName=biosample_sra&from_uid=17359332) of read accessions associated with it. Eventually this blows through our disk size estimate. Same story with SAMN30839965 (although in that case the error in Cromwell is out of memory -- it's actually out of disk well before that happens though).

SAMN37194267 has an L9 in there somewhere, but this is considered one sample with 67 runs instead of 67 different samples, so they currently break SRANWRP.

## Fails in variant calling
Examples: 
* SAMEA2534824
* SAMEA2534285
* SAMEA5225290
* SAMEA7550961
* SAMEA7552104
* SAMN01797599
* SAMN07344516
* SAMN07344518
* SAMN07344554

If you run `java -Xmx1000m -jar /bioinf-tools/Trimmomatic-0.36/trimmomatic-0.36.jar PE -threads 1 /mounted/SAMEA2534285_1.decontam.fq /mounted/SAMEA2534285_2.decontam.fq var_call_SAMEA2534285/trimmed_reads.0.1.fq.gz /dev/null var_call_SAMEA2534285/trimmed_reads.0.2.fq.gz /dev/null ILLUMINACLIP:/bioinf-tools/Trimmomatic-0.36/adapters/TruSeq3-PE-2.fa:2:30:10  MINLEN:50 -phred33` on SAMEA2534285 after decontamination, you'll note the entire thing is trimmed. Understandably, this breaks when variants are called on the resulting empty files. It's possible this wouldn't happen if we didn't downsample its one read, ERR551913, which is normally 1149 MB, but for now we're adding it to the denylists. SAMEA2534824 and SAMN01797599 have the same issue.

## Not actually TB
Input list tb_z included "307", which does link to SAMN00000188 (SRS000422), which is indeed tagged as TB. However, it is also tagged as basically everything else.

But why stop there? Get yourself a BioSample that can be it all: steph AND staph AND tuberculosis AND cdiff AND zebrafish AND salmonella AND plague AND western lowland gorilla: https://www.ncbi.nlm.nih.gov/biosample/9845

## Not on google mirror, seem to have no data, do not have a biosample accession
ERR1274706
ERR181439
ERR181441
ERR1873513
ERR3256208
ERR760606
ERR760780
ERR760898
ERR845308

## Accessions within sample groups
If you run the get-sample-from-run workflow I wrote on a single one of these, you will get 12 samples returned. It seems likely there ought to be a one-to-one relationship between runs and samples, but it's not the dot product.

It's worth noting SRS024887/SAMEA968167 and SRS024887/SAMN00009845 are particularly odd, appearing not only in multiple groups below, but also multiple unrelated studies.

SAMEA968095 (L3) and SAMEA968096 (L3) are both in this sample group table and were originally thrown out for having 12 reads returned. Since some of those reads are supposedly lineage 4.1, according to the lineage-4 specific file which was run-based (unlike the other files used to make my lineage lists, which were usually sample-based from the start), you should consider the lineage of sample in these groups to be suspect.

### sample group A
| run       	| supposed lineage
|-----------	|-----------	|
| ERR023728 	| unknown       |
| ERR023729 	| L4.7          |
| ERR023730 	| unknown       |
| ERR023731 	| L4.1          |
| ERR023732 	| L4.1          |
| ERR023733 	| unknown       |
| ERR023734 	| unknown       |
| ERR023735 	| unknown       |
| ERR023736 	| unknown       |
| ERR023737 	| L4.7          |
| ERR023738 	| L4.7          |
| ERR023739 	| L4.1          |
| ERR023740 	| L4.1          |

| sample (\*RS) 	| sample (SAM\*)  |
|-----------	    |--------------	  |
| ERS007636 	    | SAMEA968161  	  |
| ERS007637 	    | SAMEA968160  	  |
| ERS007638 	    | SAMEA968158  	  |
| ERS007640 	    | SAMEA968084  	  |
| ERS007642 	    | SAMEA968083  	  |
| ERS007644 	    | SAMEA968088  	  |
| SRS024887 	    | SAMN00009845 	  |
| ERS007646 	    | SAMEA968086  	  |
| ERS007647 	    | SAMEA968087  	  |
| ERS007649 	    | SAMEA968078  	  |
| ERS007651 	    | SAMEA968074  	  |
| ERS007652 	    | SAMEA968215  	  |
| ERS007654 	    | SAMEA968216  	  |


### sample group B
| run       	| supposed lineage       |
|-----------	|-----------	|
| ERR024348 	| unknown       |
| ERR024349 	| unknown       |
| ERR024350 	| unknown       |
| ERR024351 	| unknown       |
| ERR024352 	| unknown       |
| ERR024353 	| unknown       |
| ERR024354 	| unknown       |
| ERR024355 	| L4.8          |
| ERR024356 	| unknown       |
| ERR024357 	| unknown       |
| ERR024358 	| unknown       |
| ERR024359 	| L4.4          |

| sample (\*RS) 	| sample (SAM\*) |
|--------------	    |--------------- |
| ERS007724    	    | SAMEA968101    |
| ERS007726    	    | SAMEA968102    |
| ERS007728    	    | SAMEA968217    |
| ERS007730    	    | SAMEA968089    |
| ERS007731    	    | SAMEA968090    |
| ERS007733    	    | SAMEA968165    |
| SRS024887    	    | SAMEA968167    |
| ERS007734    	    | SAMEA968166    |
| ERS007737    	    | SAMEA968097    |
| ERS007739    	    | SAMEA968139    |
| ERS007741    	    | SAMEA968138    |
| ERS007743    	    | SAMEA968101    |

### sample group C
| run       	| supposed lineage       |
|-----------	|-----------	|
| ERR023741     | unknown       |	
| ERR023742     | unknown       |	
| ERR023743     | unknown       |	
| ERR023744     | unknown       |	
| ERR023745     | unknown       |	
| ERR023746     | L4.1          |
| ERR023747     | L4.1	        |
| ERR023748     | unknown       |
| ERR023749     | unknown       |
| ERR023750     | unknown       |
| ERR023751     | unknown       |	
| ERR023752     | unknown       |

| sample (\*RS) 	| sample (SAM\*) |
|--------------	    |--------------- |
| ERS007672         | SAMEA968096    |
| ERS007673         | SAMEA968095    |
| ERS007674         | SAMEA968094    |
| ERS007675         | SAMEA968093    |
| ERS007677         | SAMEA968092    |
| ERS007679         | SAMEA968091    |
| SRS024887         | SAMN00009845   |
| ERS007681         | SAMEA968187    |
| ERS007683         | SAMEA968186    |
| ERS007684         | SAMEA968185    |
| ERS007686         | SAMEA968184    |
| ERS007688         | SAMEA968183    |

### sample group D
| run       	| supposed lineage       |
|-----------	|-----------	|
| ERR024336     | unknown       |
| ERR024337     | unknown       |
| ERR024338     | unknown       |
| ERR024339     | unknown       |
| ERR024340     | L4.3          |
| ERR024341     | unknown       |
| ERR024342     | unknown       |
| ERR024343     | L4.3          |
| ERR024344     | L4.3          |
| ERR024345     | L4.3          |
| ERR024346     | L4.3          |
| ERR024347     | L4.3          |

| sample (\*RS) 	| sample (SAM\*) |
|--------------	    |--------------- |
| ERS007706         | SAMEA968193    |
| ERS007708         | SAMEA968191    |
| ERS007710         | SAMEA968205    |
| ERS007711         | SAMEA968206    |
| ERS007712         | SAMEA968207    |
| ERS007713         | SAMEA968122    |
| SRS024887         | SAMEA968167    |
| ERS007714         | SAMEA968209    |
| ERS007716         | SAMEA968211    |
| ERS007718         | SAMEA968135    |
| ERS007720         | SAMEA968136    |
| ERS007722         | SAMEA968137    |

### sample group E
| run       	| supposed lineage       |
|-----------	|-----------	|
| ERR023753     | unknown       |
| ERR023754     | unknown       |
| ERR023755     | unknown       |
| ERR023756     | unknown       |
| ERR023757     | L4.1          |
| ERR023758     | L4.1          |
| ERR023759     | L4.1          |
| ERR023760     | L4.1          |
| ERR023761     | L4.3          |
| ERR023762     | unknown       |
| ERR023763     | unknown       |
| ERR023764     | L4.3          |

| sample (\*RS) 	| sample (SAM\*) |
|--------------	    |--------------- |
| ERS007690         | SAMEA968182    |
| ERS007692         | SAMEA968154    |
| ERS007693         | SAMEA968153    |
| ERS007694         | SAMEA968150    |
| ERS007695         | SAMEA968149    |
| ERS007697         | SAMEA968151    |
| SRS024887	        | SAMEA968167    |
| ERS007699         | SAMEA968148    |
| ERS007701         | SAMEA968198    |
| ERS007702         | SAMEA968202    |
| ERS007703         | SAMEA968201    |
| ERS007704         | SAMEA968195    |

# Previously bad, but work now!

## Failure in prefetch
**How it's currently handled:** The invalid read accession will be skipped.

```
`prefetch.3.0.1 err: name not found while resolving query within virtual file system module - failed to resolve accession 'x' - no data ( 404 )`
```

Examples: 
* ERR760606 (part of SAMEA3231653, which has other valid reads)
* ERR760898 (part of SAMEA3231746, which has other valid reads)

I asked NLM about ERR760606 and was told there are errors in the run, and that prevented NCBI SRA from processing it properly. They also [linked the EBI version](https://www.ebi.ac.uk/ena/browser/view/ERR760606?dataType=&show=xrefs), where it can still be accessed. It's possible that `curl -s -X POST "https://locate.ncbi.nlm.nih.gov/sdl/2/locality?acc=[some_run_accesion]"` could be used to spot weird runs like this at runtime.


## Relatively large samples
**How it's currently handled:** Downsampling and really big disk size estimates.

By default, reads are downsampled if they are over 450 MB in size. However, when running on GCP, we are still beholden to disk size limits, which is why ludicrously oversized samples such as SAMN17359332 still needs to be on the denylist.

## Mixed accession types
**How it's currently handled:** The invalid read accession will be skipped, and the valid one will be downloaded. Examples include:
* ERR3825345 (SAMEA5803801)
* SRR17231608 (SAMN09651729)
* SRR17234893 (SAMN24039640)
* SRR17234897 (SAMN24042990)
* SRR3668213 (SAMN03257097)
* SRR3668214 (SAMN03257097)
* SRR3668218 (SAMN03253093)
* SRR3668219 (SAMN03253093)
* SRR5879396 (SAMN07312468)
* SRR8186770 (SAMN10417149)
* SRR8186771 (SAMN10417149)
* SRR8186772 (SAMN10417149)

## All reads fail prefetch or fasterq-dump (allerror_*.txt)
**How it's currently handled:** Exit gracefully with no FQ output.

### Read length =/= quality score

`err: row #x : READ.len(x) != QUALITY.len(x) (F)`

Examples: 
* ERR234214 (SAMEA1877221)
* ERR234218 (SAMEA1877166)
* ERR234219 (SAMEA1877131)
* ERR234231 (SAMEA1877282)
* ERR538422 (SAMEA2609926)
* ERR538423 (SAMEA2609927)
* ERR538424 (SAMEA2609928)
* ERR538425 (SAMEA2609929)
* ERR538426 (SAMEA2609930)
* ERR538427 (SAMEA2609931)
* ERR538428 (SAMEA2609932)
* ERR538429 (SAMEA2609933)
* ERR538430 (SAMEA2609934)
* ERR538431 (SAMEA2609935)
* ERR538432 (SAMEA2609936)
* SRR960962 (SAMN02339318)

### No idea, but I guess that's bad

```
2023-02-17T21:19:39 fasterq-dump.3.0.1 err: sorter.c run_producer_pool() : processed lookup rows: 35 of 36
2023-02-17T21:19:39 fasterq-dump.3.0.1 err: sorter.c execute_lookup_production() -> RC(rcVDB,rcNoTarg,rcConstructing,rcSize,rcInvalid)
2023-02-17T21:19:39 fasterq-dump.3.0.1 err: fasterq-dump.c produce_lookup_files() -> RC(rcVDB,rcNoTarg,rcConstructing,rcSize,rcInvalid)
```

Examples:
* SRR1180610 (SAMN02580571)
* SRR1180764 (SAMN02580571)

### There's no error, but that's an error (my personal favorite)

`int: no error - failed to verify`

Examples: 
* ERR2179830 (SAMEA104357625)
* ERR2179842 (SAMEA104357637)

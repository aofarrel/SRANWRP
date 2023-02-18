# denylists
A list of denylists of samples known to be problematic when fed through [myco_sra](https://github.com/aofarrel/myco) and/or this repo's pull_fastqs.wdl (specifically the pull_fq_from_biosample task). denylist_samples.txt is currently more complete, except for the ones that lack a BioSample accession entirely.

In release 1.1.7, improvements to the pull_fq_from_biosample task means that a few more edge cases are tolerated. Most samples should still be skipped entirely because they have no useful data, but a handful have at least one acceptable read accession and don't need to be avoided entirely anymore. Thus, we have **denylist_samples.txt** which is the sorted concatenation of allfail_samples.txt, samplegroup_samples.txt, and somewheredownthelane_samples.txt (ie, does not include partialfail_samples.txt).

# Why Deny?

## Some reads are invalid (partialfail_*.txt)
*pull_fq_from_biosample can handle these sample as of 1.1.7*  
Some reads within these sample fail prefetch/faster-dump 3.0.1, but not all of them.

### prefetch failure
error:
```
`prefetch.3.0.1 err: name not found while resolving query within virtual file system module - failed to resolve accession 'x' - no data ( 404 )`
```
reads affected:
```
ERR760606 (SAMEA3231653, L4.1)
ERR760898 (SAMEA3231746, L4.1)
```  
SAMEA3231653 has two reads that do succeed, and SAMEA3231746 has one that does succeed. 

I asked NLM about ERR760606 and was told there are errors in the run, and that prevented NCBI SRA from processing it properly. They also [linked the EBI version](https://www.ebi.ac.uk/ena/browser/view/ERR760606?dataType=&show=xrefs), where it can still be accessed. It's possible that `curl -s -X POST "https://locate.ncbi.nlm.nih.gov/sdl/2/locality?acc=[some_run_accesion]"` could be used to spot weird runs like this at runtime.

### mixed accession types
These BioSamples have some Illumina and some PacBio runs within them. fasterq-dump can't handle PacBio so it throws an error.
```
SRR17234897 (SAMN24042990, no lineage)
SRR3668213 (SAMN03257097, L3)
SRR3668214 (SAMN03257097, L3)
SRR5879396 (SAMN07312468, no lineage)
```

## All reads fail prefetch or fasterq-dump (allerror_*.txt)
All reads within these samples fail prefetch-3.0.1 or fasterq-dump-3.0.1

### `err: row #x : READ.len(x) != QUALITY.len(x) (F)`
```
ERR234214 (SAMEA1877221, L1.2.1)  
ERR234218 (SAMEA1877166, L3)
ERR234219 (SAMEA1877131, L3)
ERR538422 (SAMEA2609926, L2)  
ERR538423 (SAMEA2609927, L2)  
ERR538424 (SAMEA2609928, L2)  
ERR538425 (SAMEA2609929, L2)  
ERR538426 (SAMEA2609930, L2)  
ERR538427 (SAMEA2609931, L2)  
ERR538428 (SAMEA2609932, L2)  
ERR538429 (SAMEA2609933, L2)  
ERR538430 (SAMEA2609934, L2)  
ERR538431 (SAMEA2609935, L2)  
ERR538432 (SAMEA2609936, L2)  
SRR960962 (SAMN02339318, L2)  
```

### `int: no error - failed to verify`
```
ERR2179830 (SAMEA104357625, L1.2.1)
ERR2179842 (SAMEA104357637, L3)
```

### unknown error
error:
```
2023-02-17T21:19:39 fasterq-dump.3.0.1 err: sorter.c run_producer_pool() : processed lookup rows: 35 of 36
2023-02-17T21:19:39 fasterq-dump.3.0.1 err: sorter.c execute_lookup_production() -> RC(rcVDB,rcNoTarg,rcConstructing,rcSize,rcInvalid)
2023-02-17T21:19:39 fasterq-dump.3.0.1 err: fasterq-dump.c produce_lookup_files() -> RC(rcVDB,rcNoTarg,rcConstructing,rcSize,rcInvalid)
```
```
SRR1180610 (SAMN02580571)
SRR1180764 (SAMN02580571)
```

## Accessions within sample groups (samplegroups_*.txt)
If you run the get-sample-from-run workflow I wrote on a single one of these, you will get 12 samples returned. It seems likely there ought to be a one-to-one relationship between runs and samples, but it's not the dot product.

It's worth noting SRS024887/SAMEA968167 and SRS024887/SAMN00009845 are particularly odd, appearing not only in multiple groups below, but also multiple unrelated studies.

SAMEA968095 (L3) and SAMEA968096 (L3) are both in this sample group table and were originally thrown out for having 12 reads returned. Since some of those reads are supposedly lineage 4.1, according to the lineage-4 specific file which was run-based (unlike the other files used to make my lineage lists, which were usually sample-based from the start), you should consider the lineage of sample in these groups to be suspect.

### sample group A
| run       	| lineage
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
| run       	| lineage       |
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
| run       	| lineage       |
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
| run       	| lineage       |
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
| run       	| lineage       |
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

## Fails later down the pipeline (somewheredownthelane_*.txt)

### fails in variant calling

BioSample ERS3032737/SAMEA5225290 has a few of these...
```
ERR3063106
ERR3063107
ERR3063108
ERR3063109
ERR3063110
```

But SRR5818408 (SAMN07344516) and SRR5818458 (SAMN07344554) also fail.

## not on google mirror, seem to have no data, do not have a biosample accession
ERR1274706
ERR181439
ERR181441
ERR1873513
ERR3256208
ERR760606
ERR760780
ERR760898
ERR845308

## appear in list Z, but aren't TB (biosample: SRS000422/SAMN00000188/307)
SRR001703
SRR001704
SRR001705
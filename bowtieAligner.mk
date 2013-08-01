# performs bowtie alignment from reads extracted from bam files
# INPUT: bam files
# OUTPUT: bowtie aligned bam files
# OPTIONS: PHRED64 = true/false
# 		   LOCAL = true/false (preform local alignments)
# 		   RMDUP = true/false
include ~/share/modules/Makefile.inc

VPATH ?= unprocessed_bam
SAMPLE_FILE ?= samples.txt
SAMPLES ?= $(shell cat $(SAMPLE_FILE))

LOGDIR = log/bowtie.$(NOW)

BOWTIE_OPTS = -x $(BOWTIE_REF) 

LOCAL ?= false
PHRED64 ?= false
SEQ_PLATFORM ?= ILLUMINA
NUM_CORES ?= 4

DUP_TYPE ?= rmdup
NO_RECAL ?= false
NO_REALN ?= false
SPLIT_FASTQ ?= false

ifeq ($(PHRED64),true)
  BOWTIE_OPTS += --phred64
endif

ifeq ($(LOCAL),true)
  BOWTIE_OPTS += --local
endif

.SECONDARY:
.DELETE_ON_ERROR:
.PHONY: all

BAMS = $(foreach sample,$(SAMPLES),bam/$(sample).bam)

.PHONY : all bowtie_bams

all : bowtie_bams
bowtie_bams : $(BAMS) $(addsuffix .bai,$(BAMS))

# memory for human genome: ~3.2G
bowtie/bam/%.bwt.bam : fastq/%.1.fastq.gz fastq/%.2.fastq.gz
	LBID=`echo "$*" | sed 's/_[0-9]\+//'`; \
	$(call LSCRIPT_PARALLEL_MEM,4,1G,1.5G,"$(BOWTIE) $(BOWTIE_OPTS) --rg-id $* --rg \"LB:\$${LBID}\" --rg \"PL:${SEQ_PLATFORM}\" --rg \"SM:\$${LBID}\" -p $(NUM_CORES) --1 $(word 1,$^) -2 $(word 2,$^) 2> $(LOG) | $(SAMTOOLS) view -bhS - > $@")

BAM_SUFFIX := bwt.sorted.filtered

ifeq ($(NO_REALN),false)
BAM_SUFFIX := $(BAM_SUFFIX).realn
endif

ifeq ($(DUP_TYPE),rmdup)
BAM_SUFFIX := $(BAM_SUFFIX).rmdup
else ifeq ($(DUP_TYPE),markdup) 
BAM_SUFFIX := $(BAM_SUFFIX).markdup
endif

ifeq ($(NO_RECAL),false)
BAM_SUFFIX := $(BAM_SUFFIX).recal
endif

BAM_SUFFIX := $(BAM_SUFFIX).bam

bam/%.bam : bowtie/bam/%.$(BAM_SUFFIX)
	$(INIT) ln -f $< $@

include ~/share/modules/fastq.mk
include ~/share/modules/processBam.mk

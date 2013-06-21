# Run mutect on tumour-normal matched pairs
# Detect point mutations
##### DEFAULTS ######
REF ?= hg19
LOGDIR = log/mutect.$(NOW)
SAMPLE_PAIR_FILE ?= sample_pairs.txt
TUMOR_SAMPLES ?= $(shell cut -f 1 $(SAMPLE_PAIR_FILE))
NORMAL_SAMPLES ?= $(shell cut -f 2 $(SAMPLE_PAIR_FILE))
SAMPLES ?= $(TUMOR_SAMPLES) $(NORMAL_SAMPLES)
VCF_SAMPLES = 0 1

#SNP_EFF_FLAGS = -ud 0 -no-intron -no-intergenic -cancer
SNP_EFF_FLAGS = # -ud 0 -no-intron -no-intergenic

$(foreach i,$(shell seq 1 $(words $(TUMOR_SAMPLES))),$(eval normal_lookup.$(word $i,$(TUMOR_SAMPLES)) := $(word $i,$(NORMAL_SAMPLES))))
$(foreach i,$(shell seq 1 $(words $(TUMOR_SAMPLES))),$(eval tumor_lookup.$(word $i,$(NORMAL_SAMPLES)) := $(word $i,$(TUMOR_SAMPLES))))

##### MAKE INCLUDES #####
include ~/share/modules/Makefile.inc

MUTECT_JAR := /home/ngk1/software/muTect-1.1.4.jar
MUTECT = $(JAVA) -Xmx5G -jar $(MUTECT_JAR) --analysis_type MuTect

VPATH ?= bam

.DELETE_ON_ERROR:

.SECONDARY: 

.PHONY: all mutect_vcfs mutect_tables

all : mutect_vcfs mutect_tables

mutect_vcfs : $(foreach tumor,$(TUMOR_SAMPLES),vcf/$(tumor)_$(normal_lookup.$(tumor)).mutect.dp_ft.annotated.nsfp.vcf)

mutect_tables : $(foreach tumor,$(TUMOR_SAMPLES),tables/$(tumor)_$(normal_lookup.$(tumor)).mutect.dp_ft.annotated.nsfp.pass.novel.txt) $(foreach tumor,$(TUMOR_SAMPLES),mutect/tables/$(tumor)_$(normal_lookup.$(tumor)).mutect.txt)

# run mutect on each chromosome
#$(call mutect-tumor-normal-chr,tumor,normal,chr)
define mutect-tumor-normal-chr
mutect/chr_vcf/$1_$2.$3.mutect%vcf mutect/chr_tables/$1_$2.$3.mutect%txt : bam/$1%bam bam/$2%bam
	$$(call INIT_MEM,6G,10G) $$(MKDIR) mutect/chr_tables mutect/chr_vcf; $$(MUTECT) --intervals $3 --reference_sequence $$(REF_FASTA) --cosmic $$(COSMIC) --dbsnp $$(DBSNP) --input_file:tumor $$< --input_file:normal $$(word 2,$$^) -vcf mutect/chr_vcf/$1_$2.$3.mutect.vcf --out mutect/chr_tables/$1_$2.$3.mutect.txt &> $$(LOG)
endef
$(foreach chr,$(CHROMOSOMES),$(foreach tumor,$(TUMOR_SAMPLES),$(eval $(call mutect-tumor-normal-chr,$(tumor),$(normal_lookup.$(tumor)),$(chr)))))

# merge variant tables 
define mutect-tumor-normal
mutect/tables/$1_$2.mutect.txt : $$(foreach chr,$$(CHROMOSOMES),mutect/chr_tables/$1_$2.$$(chr).mutect.txt)
	$$(INIT) head -2 $$< > $$@; for table in $$^; do sed '1,2d' $$$$table >> $$@; done
endef
$(foreach tumor,$(TUMOR_SAMPLES),$(eval $(call mutect-tumor-normal,$(tumor),$(normal_lookup.$(tumor)))))

# merge variants 
define mutect-tumor-normal
vcf/$1_$2.mutect.vcf : $$(foreach chr,$$(CHROMOSOMES),mutect/chr_vcf/$1_$2.$$(chr).mutect.vcf)
	$$(call INIT_MEM,4G,6G) grep '^##' $$< > $$@; echo "##PEDIGREE=<Derived=$1,Original=$2>" >> $$@; grep '^#[^#]' $$< >> $$@; cat $$^ | grep -v '^#' | $$(VCF_SORT) $$(REF_DICT) - >> $$@ 2> $$(LOG)
endef
$(foreach tumor,$(TUMOR_SAMPLES),$(eval $(call mutect-tumor-normal,$(tumor),$(normal_lookup.$(tumor)))))

include ~/share/modules/vcftools.mk


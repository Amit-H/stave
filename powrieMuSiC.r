####################### Powrie MuSiC Tool #######################

# Metadata
## Author: Amit Halkhoree & Nicholas Ilott- Powrie Lab, Kenendy Institute of Rheumatology, University of Oxford
## Correspondance Email: amit.halkhoree@kennedy.ox.ac.uk
## Date: 04-Jan-2023
## Licence: MIT
## R Version: 4.2.1
## Version 0.02

# Description: 
## This tool is designed to provide a command line interface for cell type proportion estimations using the MuSiC algorithm 
## implemented by Xuran Wang https://doi.org/10.1038/s41467-018-08023-x.
## The tool takes bulk RNA Seq inputs from Kalisto outputs and references them versus a single cell reference set, to generate cell proportion estimations.
## The single cell reference set is known as the Powrie Album, and can be found on the shared drive of the BMRC
## For brevity, all functionality will be contained in this script.

# Usage Instructions:
## To run the script: Rscript powrieMuSiC.r -s SINGLE_CELL_EXPERIMENT_OBJECT -b BULK_DATA_FOLDER


################################################################

# Loading and installing the required packages


## Checking the existance of packages, and installing if not found
if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install(version = "3.16")

if (!require("SingleCellExperiment", quietly = TRUE)) {
  biocmanager::install("SingleCellExperiment")
}

if (!require("tximport", quietly = TRUE)) {
  biocmanager::install("tximport")
}

if (!require("biomaRt", quietly = TRUE)) {
  biocmanager::install("biomaRt")
}

if (!require("Biobase", quietly = TRUE)) {
  biocmanager::install("Biobase")
}
if (!require("devtools", quietly = TRUE)) {
  install.packages("devtools")
}
devtools::install_github("xuranw/MuSiC")

if (!require("argparse", quietly = TRUE)) {
  install.packages("argparse")
}

## Loading in the required packages
library(SingleCellExperiment)
library(tximport)
library(biomaRt)
library(Biobase)
library(MuSiC)
library(argparse)


####################### Utility Functions #######################

## Bulk RNA Seq

#' Convert TPMs to counts using Tximport from the output of Kalisto
#'
#' This function reads in a transcript mapping file and a set of input files,
#' converts the TPM values in the input files to counts using Tximport, and
#' writes the resulting counts table to a file.
#'
#' @param transcript_mapping_file Path to the transcript mapping file.
#' @param input_directory Path to the input directory containing the input files.
#' @param output_directory Path to the output directory where the counts table should be written.
#' @return A counts table
convert_to_counts <- function(transcript_mapping_file, input_directory) {
  tx2gene <- read.csv(transcript_mapping_file, header=TRUE, stringsAsFactors=FALSE, sep="\t")
  currwd <- getwd()
  setwd(input_directory)
  files <- list.files()[grep("*abundance.tsv", list.files())]
  names(files) <- gsub("_abundance.tsv", "", files)
  txi <- tximport(files, type = "kallisto", tx2gene = tx2gene, countsFromAbundance="lengthScaledTPM")
  counts <- txi$counts
  setwd(currwd)
  row.names(counts) <- gsub("\\..*", "", row.names(counts))
  write.table(counts, "counts.tsv", sep = '\t')
  return(counts)
}

#' Aggregate counts by external gene name
#'
#' This function aggregates a counts table by external gene name, using
#' Ensembl gene ID to map the counts to external gene names.
#'
#' @param counts A counts table.
#' @return The aggregated counts table.
aggregate_counts_by_gene_name <- function(counts) {
  ensembl <- useMart('ensembl', dataset = 'mmusculus_gene_ensembl')
  attributes = c("ensembl_gene_id", "external_gene_name")
  gene_info = getBM(attributes = attributes,
                    filters = 'ensembl_gene_id', 
                    values = row.names(counts),
                    mart = ensembl)
  row.names(gene_info) <- gene_info$ensembl_gene_id
  counts <- counts[gene_info$ensembl_gene_id,]
  counts <- aggregate(counts, by=list(gene_info$external_gene_name), FUN='sum')
  row.names(counts) <- counts$Group.1
  counts <- counts[,2:ncol(counts)]
  counts <- as.matrix(counts)
  counts <- counts[-1,]
  return(counts)
}



#' Convert counts table to ExpressionSet object
#'
#' This function takes a counts table and returns an ExpressionSet object.
#'
#' @param counts A counts table.
#' @return An ExpressionSet object.
bulkdata <- function(counts){
  bulkexp_set <- ExpressionSet(assayData = counts)
  bulk.mtx = exprs(bulkexp_set)
  return(bulk.mtx)
}


## Single Cell RNA Seq

#' Read SingleCellExperiment object from file
#'
#' This function reads a SingleCellExperiment (SCE) object from a file and
#' returns the object.
#'
#' @param file Path to the file containing the SCE object.
#' @return The SCE object.
readSCE <- function(file){
  sce <- readRDS(file)
  return(sce)
}

## MuSiC

#' Estimate cell type proportions using MuSiC
#'
#' This function estimates cell type proportions using the MuSiC package. It takes
#' an expression matrix and a SingleCellExperiment object and returns the
#' MuSiC estimations object.
#'
#' @param bulk.mtx An expression matrix.
#' @param sc.sce A SingleCellExperiment object.
#' @return The MuSiC estimations object.
estimate_cell_type_proportions <- function(bulk.mtx, sc.sce) {
  estimations <- music_prop(bulk.mtx = bulk.mtx, 
                            sc.sce = sc.sce, 
                            clusters = 'celltypes',
                            samples = 'sampleIDs', 
                            select.ct = NULL , 
                            verbose = T)
  est_cell_types <- t(estimations$Est.prop.weighted)
  return(est_cell_types)
}

## Input Validation

#rds_type <- function(string) {
#  if (!grepl("\\.RDS$", string)) {
#    stop(paste0(string, " is not an RDS file"), call.=FALSE)
#  }
#  return(string)
#}
#
#dir_type <- function(string) {
#  if (!dir.exists(string)) {
#    stop(paste0(string, " is not a directory"), call.=FALSE)
#  }
#  return(string)
#}

####################### Pipeline #######################

# Parse command line arguments
arg_parser <- ArgumentParser()
arg_parser$add_argument("-s", "--sce", dest="sce_file",
                        required=TRUE,
                        help="path to the Single Cell Expression Object within the Powrie Album")

arg_parser$add_argument("-b", "--bulk", dest="bulk_dir",
                        required=TRUE,
                        help="path to the directory containing the bulk Kalisto outputs")

arguments <- arg_parser$parse_args()

# Load the single cell experiment object
sce <- readSCE(arguments$sce_file)

# Convert the kalisto output to a bulk mtx object
counts <- convert_to_counts("/well/powrie/shared/kelsey_deconv/transcripts2genes.tsv",
                  arguments$bulk_dir)

counts <- aggregate_counts_by_gene_name(counts)

bulk.mtx <- bulkdata(counts = counts)

# Run MuSiC and isolate the MuSiC estimations
est_cell_types <- estimate_cell_type_proportions(bulk.mtx, sce)
write.table(est_cell_types, "est_cell_types.tsv", sep="\t")

print('Done!')






# stave

> Stave - the lines which music is written on 

## Description: 
This tool is designed to provide a command line interface for cell type proportion estimations using the MuSiC algorithm implemented by Xuran Wang https://doi.org/10.1038/s41467-018-08023-x. The tool takes bulk RNA Seq inputs from Kalisto outputs and references them versus a single cell reference set, to generate cell proportion estimations. The single cell reference set is known as the Powrie Album, and can be found on the shared drive of the BMRC. For brevity, all functionality will be contained in this script.

## Usage Instructions:
To run the script: `Rscript powrieMuSiC.r -s SINGLE_CELL_EXPERIMENT_OBJECT -b BULK_DATA_FOLDER`

## To do list:
1. Add input validation
2. Add Powrie Album single cell objects
3. Add tx2gene in a data folder
4. Allow user to specify species and gene identifiers (ensemble etc) for biomaRt

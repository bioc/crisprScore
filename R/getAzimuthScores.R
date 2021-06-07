#' @title Calculate on-target sgRNA activity scores for Cas9 using Azimuth
#' @description Calculate on-target sgRNA activity scores for
#'     CRISPR/Cas9-induced knockout using the Azimuth scoring method.
#'     The Azimuth algorithm is an improvement upon the commonly-used
#'     'Rule Set 2', also developed by the Doench lab. 
#' 
#' @param sequences Character vector of 30bp sequences needed for
#'     Azimuth scoring, see details below.
#' @param fork Set to \code{TRUE} to preserve changes to the R
#'     configuration within the session.
#' 
#' @details The input sequences for Azimuth scoring require 4 nucleotides
#'     upstream of the protospacer sequence, the protospacer sequence
#'     itself (23 nucleotides) and 3 nucleootides downstream of the protospacer
#'     sequence, for a total of 30 nucleotides: [4nt][20nt-spacer][NGG][3nt].
#'     Note that a canonical PAM sequence (NGG) is required for Azimuth. 
#' 
#' @return \strong{getAzimuthScores} returns a data.frame with \code{sequence} 
#'     and \code{score} columns. The Azimuth score takes on a value between 0
#'     and 1. A higher score indicates higher knockout efficiency.
#' 
#' @references 
#' Doench, J., Fusi, N., Sullender, M. et al. Optimized sgRNA design to
#'     maximize activity and minimize off-target effects of CRISPR-Cas9.
#'     Nat Biotechnol 34, 184–191 (2016).
#'     \url{https://doi.org/10.1038/nbt.3437}.
#' 
#' @author Jean-Philippe Fortin
#' 
#' @examples 
#' \donttest{
#' flank5 <- "ACCT" #4bp
#' spacer <- "ATCGATGCTGATGCTAGATA" #20bp
#' pam    <- "AGG" #3bp 
#' flank3 <- "TTG" #3bp
#' input  <- paste0(flank5, spacer, pam, flank3) 
#' results <- getAzimuthScores(input)
#' }
#' 
#' @export
#' @importFrom basilisk basiliskStart basiliskStop basiliskRun
getAzimuthScores <- function(sequences, fork=FALSE){
    sequences <- .checkSequenceInputs(sequences)
    if (unique(nchar(sequences))!=30){
        stop("Provided sequences must have length 30nt ",
             "([4nt][20nt-spacer][PAM][3nt]).")
    }
    pams  <- substr(sequences,26,27)
    valid <- pams=="GG"
    if (sum(valid)!=length(pams)){
        stop("Positions 26 and 27 of the sequences must be G",
             " nucleotides (canonical PAM sequences required).")
    }
    results <- basiliskRun(env=env_azimuth,
                           shared=FALSE,
                           fork=fork,
                           fun=.azimuth_python, 
                           sequences=sequences)
    return(results)
}


#' @importFrom reticulate source_python
#' @importFrom reticulate np_array
#' @importFrom reticulate import_from_path
.azimuth_python <- function(sequences){

    dir <- system.file("python",
                       "azimuth",
                       package="crisprScore",
                       mustWork=TRUE)
    azimuth <- import_from_path("getAzimuth", dir)

    df <- data.frame(sequence=sequences,
                     score=NA_real_,
                     stringsAsFactors=FALSE)
    good <- !grepl("N", sequences)
    sequences.valid <- sequences[good]
    ns <- length(sequences.valid)
    if (ns>0){
        if (ns==1){
            sequences.valid <- rep(sequences.valid,2)
            scores <- azimuth$getAzimuth(np_array(sequences.valid))
            scores <- scores[1]
        } else {
            scores <- azimuth$getAzimuth(np_array(sequences.valid)) 
        }
        df$score[good] <- scores
    }
    return(df)
}
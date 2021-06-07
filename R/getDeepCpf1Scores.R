#' @title Calculate on-target sgRNA activity scores for Cas12a using DeepCpf1
#' @description Calculate on-target sgRNA activity scores for
#'     CRISPR/Cas12a-induced knockout using the DeepCpf1 scoring method.
#' 
#' @param sequences Character vector of 34bp sequences needed for DeepCpf1
#'     scoring, see details below.
#' @param convertPAM Should non-canonical PAM sequences be converted to
#'     TTTC? TRUE by default. 
#' 
#' @details The input sequences for DeepCpf1 scoring require 4 nucleotides
#'     upstream of the protospacer sequence, the protospacer sequence
#'     itself (4bp PAM sequence + 23bp spacer sequence) and 3 nucleootides 
#'     downstream of the protospacer sequence, for a total of 34 nucleotides.
#'     If \code{convertPAM} is set to \code{TRUE}, any non-canonical PAM
#'     sequence will be convert to TTTC for scoring purposes.
#' 
#' @return \strong{getDeepCpf1Scores} returns a data.frame with \code{sequence}
#'     and \code{score} columns. The DeepCpf1 score takes on a value between 0
#'     and 1. A higher score indicates higher knockout efficiency.
#' 
#' @references 
#' Kim, H., Min, S., Song, M. et al. Deep learning improves prediction of
#'     CRISPR–Cpf1 guide RNA activity. Nat Biotechnol 36, 239–241 (2018).
#'     \url{https://doi.org/10.1038/nbt.4061}.
#' 
#' @author Jean-Philippe Fortin
#' 
#' @examples
#' \donttest{
#' flank5 <- "ACC" #3bp
#' pam    <- "TTTT" #4bp
#' spacer <- "AATCGATGCTGATGCTAGATATT" #23bp
#' flank3 <- "AAGT" #4bp
#' input  <- paste0(flank5, pam, spacer, flank3) 
#' results <- getDeepCpf1Scores(input)
#' }
#' 
#' @inheritParams getAzimuthScores
#' @export 
#' @importFrom basilisk basiliskStart basiliskStop basiliskRun
getDeepCpf1Scores <- function(sequences,
                              convertPAM=TRUE,
                              fork=FALSE){
    sequences <- .checkSequenceInputs(sequences)
    if (unique(nchar(sequences))!=34){
        stop("Provided sequences must have length 34nt",
             " ([4nt][TTTV][23mer][3nt]).")
    }
    if (convertPAM){
        pams <- substr(sequences, 5,8)
        wh <- which(!pams %in% c("TTTC", "TTTG", "TTTA"))
        if (length(wh)>0){
            sequences[wh] <- vapply(sequences[wh], function(x){
                paste0(substr(x,1,4), "TTTC",substr(x, 9,34), collapse="")
            }, FUN.VALUE="character")
        }
    }
    results <- basiliskRun(env=env_deepcpf1,
                           shared=FALSE,
                           fork=fork,
                           fun=.deepcpf1_python, 
                           sequences=sequences)
    return(results)
}

#' @importFrom reticulate import_from_path
#' @importFrom reticulate np_array
#' @importFrom reticulate py_suppress_warnings
.deepcpf1_python <- function(sequences){

    dir <- system.file("python",
                       "deepcpf1",
                       package="crisprScore",
                       mustWork=TRUE)
    deepcpf1 <- import_from_path("getDeepCpf1", path=dir)
    
    df <- data.frame(sequence=sequences,
                     score=NA_real_,
                     stringsAsFactors=FALSE)
    good <- !grepl("N", sequences)
    sequences.valid <- sequences[good]
    if (length(sequences.valid)>0){
        sequences_array <- np_array(sequences.valid)
        scores <- py_suppress_warnings(deepcpf1$getDeepCpf1(sequences_array))
        scores <- scores/100
        df$score[good] <- scores
    } 
    return(df)
}
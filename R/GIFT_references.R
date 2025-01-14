#' References available in GIFT
#'
#' Retrieve the metadata of every reference accessible in GIFT
#'
#' @param GIFT_version character string defining the version of the GIFT
#'  database to use. The function retrieves by default the most up-to-date
#'  version.
#' 
#' @param api character string defining from which API the data will be
#' retrieved.
#' 
#' @return
#' A data frame with 14 columns.
#'
#' @details Here is what each column refers to:
#' 
#' \emph{ref_ID} - Identification number of the reference\cr
#' \emph{ref_long} - Full reference for the reference\cr
#' \emph{geo_entity_ref} - Name of the location\cr
#' \emph{type} - What type the source is\cr
#' \emph{subset} - What information regarding the status of species is
#'  available\cr
#' \emph{taxon_ID} - Identification number of the group of taxa available\cr
#' \emph{taxon_name} - Name of the group of taxa available\cr
#' \emph{checklist} - Is the source a checklist\cr
#' \emph{native_indicated} - Whether native status of species is available in
#'  the source\cr
#' \emph{natural_indicated} - Whether naturalized status of species is
#' available in the source\cr
#' \emph{end_ref} - Whether endemism information is available in the source\cr
#' \emph{traits} - Whether trait information is available in the source\cr
#' \emph{restricted} - Whether the access to this reference is restricted\cr
#' \emph{proc_date} - When the source was processed
#'
#' @references
#'      Weigelt, P, König, C, Kreft, H. GIFT – A Global Inventory of Floras and
#'      Traits for macroecology and biogeography. J Biogeogr. 2020; 47: 16– 43.
#'      https://doi.org/10.1111/jbi.13623
#'
#' @seealso [GIFT::GIFT_checklist()]
#'
#' @examples
#' \dontrun{
#' ex <- GIFT_references()
#' }
#' 
#' @importFrom jsonlite read_json
#' @importFrom dplyr mutate_at
#' 
#' @export

GIFT_references <- function(
    api = "https://gift.uni-goettingen.de/api/extended/",
    GIFT_version = "latest"){
  # 1. Controls ----
  if(length(api) != 1 || !is.character(api)){
    stop("api must be a character string indicating which API to use.")
  }
  
  # GIFT_version
  gift_version <- jsonlite::read_json(
    "https://gift.uni-goettingen.de/api/index.php?query=versions",
    simplifyVector = TRUE)
  if(length(GIFT_version) != 1 || is.na(GIFT_version) ||
     !is.character(GIFT_version) || 
     !(GIFT_version %in% c(unique(gift_version$version),
                           "latest", "beta"))){
    stop(c("'GIFT_version' must be a character string stating what version
    of GIFT you want to use. Available options are 'latest' and the different
           versions."))
  }
  if(GIFT_version == "latest"){
    GIFT_version <- gift_version[nrow(gift_version), "version"]
  }
  if(GIFT_version == "beta"){
    message("You are asking for the beta-version of GIFT which is subject to
            updates and edits. Consider using 'latest' for the latest stable
            version.")
  }
  
  # 2. Query ----
  tmp <- jsonlite::read_json(paste0(
    api, "index", ifelse(GIFT_version == "beta", "", GIFT_version),
    ".php?query=references"), simplifyVector = TRUE)
  
  tmp <- dplyr::mutate_at(
    tmp, c("ref_ID","taxon_ID","checklist","native_indicated",
           "natural_indicated","end_ref","traits"), as.numeric)
  
  if("restricted" %in% names(tmp)){
    tmp$restricted <- as.numeric(tmp$restricted)
  }
  
  return(tmp)
}

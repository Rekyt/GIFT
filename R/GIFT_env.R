#' Environmental data for GIFT checklists
#'
#' Retrieve environmental data associated to each GIFT checklists.
#' They can come as rasters or shapefiles (miscellaneous)
#'
#' @param entity_ID A vector defining the ID of the lists to retrieve.
#' `NULL` by default, in that case, every list from GIFT is retrieved.
#'
#' @param miscellaneous character vector or list defining the miscellaneous
#' data to retrieve.
#' 
#' @param rasterlayer character vector or list defining the raster
#' data to retrieve.
#' 
#' @param sumstat Vector or list indicating the desired summary statistics out 
#' of c("min", "q05", "q10", "q20", "q25", "q30", "q40", "med", "q60", "q70", 
#' "q75", "q80", "q90", "q95", "max", "mean", "sd", "modal", "unique_n", "H", 
#' "n") used to aggregate the information coming from the raster layers. If 
#' sumstat is a vector, the same summary statistics are used for all raster 
#' layers. If sumstat is a list, the first element defines the summary 
#' statistics for the first raster layer, the second for the second and so
#' on.\cr
#' \strong{Important note} Some summary statistics may not be informative
#' depending on the environmental layer you ask for. For example, it is not
#' relevant to retrieve the mean of soil classes for a polygon. The mode or
#' Shannon index are more suitable in that case.
#' 
#' @param GIFT_version character string defining the version of the GIFT
#'  database to use. The function retrieves by default the most up-to-date
#'  version.
#' 
#' @param api character string defining from which API the data will be
#' retrieved.
#' 
#' @return A data frame with the environmental values per polygon (entity_ID).
#'
#' @details The columns of the data.frame are the following:
#' 
#' \emph{entity_ID} - Identification number of the polygon\cr
#' \emph{geo_entity} - Name of the polygon\cr
#' The other columns relate to the environmental variables the user asked for.
#'
#' @references
#'      Weigelt, P, König, C, Kreft, H. GIFT – A Global Inventory of Floras and
#'      Traits for macroecology and biogeography. J Biogeogr. 2020; 47: 16– 43.
#'      https://doi.org/10.1111/jbi.13623
#'
#' @seealso [GIFT::GIFT_env_meta_misc()] and [GIFT::GIFT_env_meta_raster()]
#'
#' @examples
#' \dontrun{
#' ex <- GIFT_env(miscellaneous = "perimeter")
#' ex <- GIFT_env(entity_ID = c(1,5), miscellaneous = c("perimeter", "biome"))
#' 
#' ex <- GIFT_env(entity_ID = c(1,5),
#'                miscellaneous = c("perimeter", "biome"),
#'                rasterlayer = c("mn30_grd", "wc2.0_bio_30s_01"),
#'                sumstat = "mean")
#' 
#' ex <- GIFT_env(entity_ID = c(1,5),
#'                miscellaneous = c("perimeter", "biome"),
#'                rasterlayer = c("mn30_grd", "wc2.0_bio_30s_01"),
#'                sumstat = c("mean", "med"))
#' 
#' ex <- GIFT_env(entity_ID = c(1,5),
#'                miscellaneous = c("perimeter", "biome"),
#'                rasterlayer = c("mn30_grd", "wc2.0_bio_30s_01"),
#'                sumstat = list(c("mean", "med"), "max"))
#' 
#' }
#' 
#' @importFrom jsonlite read_json
#' @importFrom tidyr pivot_wider
#' @importFrom purrr reduce
#' @importFrom dplyr left_join full_join mutate_if
#' 
#' @export

GIFT_env <- function(
    entity_ID = NULL,
    miscellaneous = "area", rasterlayer = NULL,
    sumstat = "mean",
    GIFT_version = "latest",
    api = "https://gift.uni-goettingen.de/api/extended/"){
  
  # 1. Controls ----
  if(!is.character(unlist(sumstat)) || 
     !(all(unlist(sumstat) %in% c(
       "min", "q05", "q10", "q20", "q25", "q30", "q40", 
       "med", "q60", "q70", "q75", "q80", "q90", "q95", 
       "max", "mean", "sd", "modal", "unique_n", "H", "n")))
  ){
    stop('sumstat needs to be a character vector including one or more of the 
         following items: c("min", "q05", "q10", "q20", "q25", "q30", "q40", 
         "med", "q60", "q70", "q75", "q80", "q90", "q95", "max", "mean", "sd", 
         "modal", "unique_n", "H", "n")')
  }
  
  if(length(api) != 1 || !is.character(api)){
    stop("api must be a character string indicating which API to use.")
  }
  
  if(length(GIFT_version) != 1 || is.na(GIFT_version) ||
     !is.character(GIFT_version)){
    stop(c("'GIFT_version' must be a character string stating what version
    of GIFT you want to use. Available options are 'latest' and the different
           versions."))
  }
  if(GIFT_version == "latest"){
    gift_version <- jsonlite::read_json(
      "https://gift.uni-goettingen.de/api/index.php?query=versions",
      simplifyVector = TRUE)
    GIFT_version <- gift_version[nrow(gift_version), "version"]
  }
  
  gift_env_meta_misc <- GIFT_env_meta_misc(api = api,
                                           GIFT_version = GIFT_version)
  if(!is.null(miscellaneous) &&
     !(all(miscellaneous %in% gift_env_meta_misc$variable))){
    stop(c("'miscellaneous' must be a character string stating what
           miscellaneous variable(s) you want to retrieve. Run
           GIFT_env_meta_misc() to see available options."))
  }
  
  suppressMessages(
    gift_env_meta_raster <- GIFT_env_meta_raster(api = api,
                                                 GIFT_version = GIFT_version))
  if(!is.null(rasterlayer) &&
     !(all(rasterlayer %in% gift_env_meta_raster$layer_name))){
    stop(c("'rasterlayer' must be a character string stating what
           raster layer(s) you want to retrieve data from. Run
           GIFT_env_meta_raster() to see available options."))
  }
  
  # 2. Query ----
  ## 2.1. Miscellaneous data ----
  if(is.null(miscellaneous) | length(miscellaneous) == 0){
    tmp_misc <- jsonlite::read_json(paste0(
      api, "index", ifelse(GIFT_version == "beta", "", GIFT_version),
      ".php?query=geoentities_env_misc"),
      simplifyVector = TRUE)
  } else{
    tmp_misc <- jsonlite::read_json(paste0(
      api, "index", ifelse(GIFT_version == "beta", "", GIFT_version),
      ".php?query=geoentities_env_misc&envvar=",
      paste(miscellaneous, collapse = ",")),
      simplifyVector = TRUE)
  }
  
  ## 2.2. Raster data ----
  
  # Query
  if(!(is.null(rasterlayer) | length(rasterlayer) == 0 |
       is.null(sumstat) | length(sumstat) == 0)){
    
    # Preparing sumstat => list with sumstats repeated
    if(is.vector(sumstat) & !is.list(sumstat)){
      sumstat <- list(sumstat)
      sumstat <- rep(sumstat, length(rasterlayer))
    }
    
    # Collapsing summary statistics together
    sumstat_collapse <- lapply(sumstat,
                               function(x) paste(x, collapse = ","))
    tmp_raster <- list()
    
    for(i in seq_along(rasterlayer)){
      tmp_raster[[i]] <- jsonlite::read_json(paste0(
        api, "index", ifelse(GIFT_version == "beta", "", GIFT_version),
        ".php?query=geoentities_env_raster&layername=", rasterlayer[i],
        "&sumstat=", sumstat_collapse[[i]]),
        simplifyVector = TRUE)
      
      # Spreading tmp
      tmp_raster[[i]] <- tidyr::pivot_wider(
        tmp_raster[[i]],
        names_from = "layer_name",
        values_from = sumstat[[i]],
        names_glue = "{.value}_{layer_name}")
      
      # Numeric raster columns
      tmp_raster[[i]] <- dplyr::mutate_if(tmp_raster[[i]], is.character,
                                          as.numeric)
    }
    
    # Join list elements together
    tmp_raster <- purrr::reduce(tmp_raster, dplyr::full_join, by = "entity_ID")
    
    # Combining with tmp_misc
    tmp_misc$entity_ID <- as.numeric(tmp_misc$entity_ID)
    tmp_misc <- dplyr::left_join(tmp_misc, tmp_raster, by = "entity_ID")
  }
  
  # Sub-setting the entity_ID
  if(!is.null(entity_ID)){
    tmp_misc <- tmp_misc[tmp_misc$entity_ID %in% entity_ID, ]
  }
  
  # Remove rows where all columns but entity_ID and geo_entity are NAs
  tmp_misc <- tmp_misc[rowSums(is.na(tmp_misc)) != (ncol(tmp_misc)-2), ]
  
  return(tmp_misc)
}

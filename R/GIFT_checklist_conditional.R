#' GIFT checklists
#'
#' Retrieve meta data on GIFT checklists for regions that are covered by 
#' checklists jointly fulfilling specific criteria.
#'
#' @param taxon_name Character string corresponding to the taxonomic group
#' of interest.
#' 
#' @param ref_included Character, options are 'all', 'native',
#' 'native and naturalized', 'native and historically introduced',
#' 'endangered', 'endemic', 'naturalized', 'other subset'
#'
#' @param ref_excluded A vector listing potential ref_IDs that shall be ignored 
#' when assembling the set of regions and checklists fulfilling the given 
#' criteria. Checklists from these references will not be returned. NULL by 
#' default.
#'  
#' @param type_ref Character, options are 'Account', 'Catalogue', 'Checklist',
#' 'Flora', 'Herbarium collection', 'Key', 'Red list', 'Report',
#' 'Species Database', 'Survey'
#' 
#' @param entity_class Character, options are 'Island', 'Island/Mainland',
#' 'Mainland', 'Island Group', 'Island Part'
#' 
#' @param native_indicated Boolean, whether only lists where native status
#' is available should be retrieved.
#' 
#' @param natural_indicated Boolean, whether only lists where natural status
#' is available should be retrieved.
#' 
#' 
#' @param end_ref Boolean, whether only lists where endemism at the reference
#' level is available should be retrieved.
#'  
#' @param end_list Boolean, whether only lists where endemism at the list level
#' is available should be retrieved.
#' 
#' @param suit_geo Boolean, whether only suitable polygons should be retrieved.
#' 
#' @param complete_taxon Boolean, default TRUE.
#' 
#' @param list_set default NULL. If not, a vector of identification numbers of
#' GIFT checklists.
#' 
#' @param taxonomy default NULL. If not, it has to be the taxonomy table (see
#' GIFT_taxonomy()).
#' 
#' @param api character string defining from which API the data will be
#' retrieved.
#' 
#' @param GIFT_version character string defining the version of the GIFT
#'  database to use. The function retrieves by default the most up-to-date
#'  version.
#' 
#' @return
#' A data frame with 16 columns.
#'
#' @details Here is what each column refers to:
#' 
#' \emph{ref_ID} - Identification number of each reference.\cr
#' \emph{type} - What type the source is.\cr
#' \emph{subset} - What information regarding the status of species is
#' available.\cr
#' \emph{native_indicated} - Whether native status of species is available in
#'  the source.\cr
#' \emph{natural_indicated} - Whether naturalized status of species is
#' available in the source.\cr
#' \emph{end_ref} - Whether endemism information is available in the source.\cr
#' \emph{restricted} - Whether the access to this reference is restricted.\cr
#' \emph{taxon_ID} - Identification number of species.\cr
#' \emph{list_ID} - Identification number of each list.\cr
#' \emph{end_list} - Whether endemism information is available in the list.\cr
#' \emph{entity_ID} - Identification number of the polygon of the list.\cr
#' \emph{geo_entity} - Name of the location.\cr
#' \emph{suit_geo} - Is the polygon suitable.\cr
#' \emph{entity_class} - Type of polygon.\cr
#' \emph{entity_type} - Name of the location.\cr
#' \emph{taxon_name} - Name of the group of taxa available.
#' 
#' @references
#'      Weigelt, P, König, C, Kreft, H. GIFT – A Global Inventory of Floras and
#'      Traits for macroecology and biogeography. J Biogeogr. 2020; 47: 16– 43.
#'      https://doi.org/10.1111/jbi.13623
#'
#' @seealso [GIFT::GIFT_checklist_raw()]
#'
#' @examples
#' \dontrun{
#' ex <- GIFT_checklist_conditional(taxon_name = "Embryophyta", 
#' ref_included = c("all", "native", "native and naturalized",
#' "native and historically introduced", "endangered",
#' "endemic", "naturalized", "other subset")[1:4],
#' type_ref = c("Account", "Catalogue", "Checklist","Flora",
#' "Herbarium collection", "Key", "Red list", "Report", "Species Database",
#'  "Survey"),
#'  entity_class = c("Island", "Island/Mainland", "Mainland", "Island Group",
#'  "Island Part"),
#'  native_indicated = FALSE, natural_indicated = FALSE, end_ref = FALSE,
#'  end_list = FALSE, suit_geo = TRUE, complete_taxon = TRUE,
#'  list_set = NULL, taxonomy = NULL)
#' 
#' }
#' 
#' @importFrom jsonlite read_json
#' @importFrom dplyr left_join mutate group_by ungroup filter select mutate_at
#' 
#' @export

GIFT_checklist_conditional <- function(
    taxon_name = "Tracheophyta",
    ref_included = c("all", "native", "native and naturalized",
                     "native and historically introduced", "endangered",
                     "endemic", "naturalized", "other subset")[1:4],
    ref_excluded = NULL,
    type_ref = c("Account", "Catalogue", "Checklist","Flora",
                 "Herbarium collection", "Key", "Red list", "Report",
                 "Species Database", "Survey"),
    entity_class = c("Island", "Island/Mainland", "Mainland", "Island Group",
                     "Island Part"),
    native_indicated = FALSE, natural_indicated = FALSE, end_ref = FALSE,
    end_list = FALSE, suit_geo = FALSE,
    complete_taxon = TRUE,
    GIFT_version = "latest", 
    api = "https://gift.uni-goettingen.de/api/extended/",
    list_set = NULL, taxonomy = NULL){
  
  # 1. Controls ----
  if(length(taxon_name) != 1 || is.na(taxon_name) ||
     !is.character(taxon_name)){
    stop("taxon_name is incorrect. It must be a character string among one of
         the taxonomic groups available in GIFT. To check them all, run
         'GIFT_taxonomy()'.")
  }
  
  if(any(is.na(ref_included)) || !is.character(ref_included) || 
     !(all(ref_included %in% c("all", "native", "native and naturalized",
                               "native and historically introduced",
                               "endangered", "endemic", "naturalized",
                               "other subset")))){
    stop(c("'ref_included' must be a character string stating what information
           should be available in the lists you retrieve (e.g. only references
           where endemic status is indicated). Available options are 'all',
           'native', 'native and naturalized',
           'native and historically introduced', 'endangered',
           'endemic', 'naturalized', 'other subset'"))
  }
  
  if(!is.null(ref_excluded) & !is.character(ref_excluded) & 
     !is.numeric(ref_excluded)){
    stop("'ref_excluded' must be a character string or a numeric stating the
         identification numbers of the references (ref_ID) that shall be 
         ignored.")
  }
  
  if(any(is.na(type_ref)) || !is.character(type_ref) || 
     !(all(type_ref %in% c("Account", "Catalogue", "Checklist","Flora",
                           "Herbarium collection", "Key", "Red list",
                           "Report", "Species Database", "Survey")))){
    stop(c("'type_ref' must be a character string stating what type of
    references you want to retrieve. Available options are 'Account',
    'Catalogue', 'Checklist','Flora', 'Herbarium collection', 'Key',
    'Red list', 'Report', 'Species Database', 'Survey'"))
  }
  
  if(any(is.na(entity_class)) || !is.character(entity_class) || 
     !(all(entity_class %in% c("Island", "Island/Mainland", "Mainland",
                               "Island Group", "Island Part")))){
    stop(c("'entity_class' must be a character string stating what class of
    polygons you want to retrieve. Available options are 'Island',
    'Island/Mainland', 'Mainland', 'Island Group', 'Island Part'."))
  }
  
  if(length(native_indicated) != 1 || !is.logical(native_indicated) ||
     is.na(native_indicated)){
    stop("'native_indicated' must be a boolean stating if you want the
         native status of species to be available.")
  }
  
  if(length(natural_indicated) != 1 || !is.logical(natural_indicated) ||
     is.na(natural_indicated)){
    stop("'natural_indicated' must be a boolean stating if you want to
         know whether species were naturalized or not.")
  }
  
  if(length(end_ref) != 1 || !is.logical(end_ref) || is.na(end_ref)){
    stop("'end_ref' must be a boolean stating if you want the endemic
         status at the reference level to be available.")
  }
  
  if(length(end_list) != 1 || !is.logical(end_list) || is.na(end_list)){
    stop("'end_list' must be a boolean stating if you want the endemic
         status at the list level to be available.")
  }
  
  if(length(suit_geo) != 1 || !is.logical(suit_geo) || is.na(suit_geo)){
    stop("'suit_geo' must be a boolean stating if you want to retrieve
         lists associated to a suitable polygon or not.")
  }
  
  if(length(complete_taxon) != 1 || !is.logical(complete_taxon) ||
     is.na(complete_taxon)){
    stop("'complete_taxon' must be a boolean stating if you want to retrieve
         references that cover entirely or not the required taxonomic group.")
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
  if(GIFT_version == "beta"){
    message("You are asking for the beta-version of GIFT which is subject to
            updates and edits. Consider using 'latest' for the latest stable
            version.")
  }
  
  if(!is.null(taxonomy)){
    if(!is.data.frame(taxonomy) ||
       !(all(c("taxon_ID", "taxon_name", "taxon_author", "taxon_lvl", "lft",
               "rgt") %in% colnames(taxonomy)))){
      stop("Taxonomy must be a dataframe with specific column names.
         See GIFT_taxonomy().")
    }
  }
  
  # Visible binding for global variable
  rgt <- lft <- entity_ID <- range_covered <- range_covered_max <- NULL
  taxon_author <- taxon_lvl <- NULL
  
  # 2. Query ----
  # List_set query
  if(is.null(list_set)){
    list_set <- jsonlite::read_json(
      paste0(api, "index", ifelse(GIFT_version == "beta", "", GIFT_version),
             ".php?query=lists"), simplifyVector = TRUE)
  }
  # Taxonomy query
  if(is.null(taxonomy)){
    taxonomy <- jsonlite::read_json(
      paste0(api, "index", ifelse(GIFT_version == "beta", "", GIFT_version),
             ".php?query=taxonomy"), simplifyVector = TRUE)
  }
  
  # Define tax_group
  tax_group <- taxonomy[which(taxonomy$taxon_name == taxon_name), "taxon_ID"]
  
  # Numeric columns
  taxonomy <- dplyr::mutate_at(taxonomy, c("lft", "rgt"), as.numeric)
  
  left_border <- taxonomy[which(taxonomy$taxon_ID == tax_group), "lft"]
  right_border <- taxonomy[which(taxonomy$taxon_ID == tax_group), "rgt"]
  
  included_taxa_below <- taxonomy[which(taxonomy$lft >= left_border &
                                          taxonomy$rgt <= right_border),
                                  "taxon_ID"]
  included_taxa_above <- taxonomy[which(taxonomy$lft < left_border &
                                          taxonomy$rgt > right_border),
                                  "taxon_ID"]
  included_taxa <- c(included_taxa_below, included_taxa_above)
  
  # Remove ref_IDs to be ignored
  if(!is.null(ref_excluded)){
    list_set <- list_set[which(!list_set$ref_ID %in% 
                                 as.numeric(ref_excluded)), ]
  }
  
  # Subset of lists based on the taxonomy
  list_set <- list_set[which(list_set$taxon_ID %in% included_taxa), ]
  
  # Subset of lists based on floristic coverage (alien, endemics, etc)
  list_set <- list_set[which(list_set$subset %in% ref_included), ]
  
  # Subset of lists based on reference type (checklist, flora, etc)
  list_set <- list_set[which(list_set$type %in% type_ref), ]
  
  # Subset of lists based on entity class (island, mainland, etc)
  list_set <- list_set[which(list_set$entity_class %in% entity_class), ]
  
  # Subset of lists based on whether nativeness is indicated
  if(native_indicated){
    list_set <- list_set[which(list_set$native_indicated == "1"), ] # see TODO
  }
  
  # Subset of lists based on whether naturalization is indicated
  if(natural_indicated){
    list_set <- list_set[which(list_set$natural_indicated == "1"), ] # see TODO
  }
  
  # Subset of lists based on whether endemic ref is indicated
  if(end_ref){
    list_set <- list_set[which(list_set$end_ref == "1"), ] # see TODO
  }
  
  # Subset of lists based on whether endemic list is indicated
  if(end_list){
    list_set <- list_set[which(list_set$end_list == "1"), ]
  }
  
  # Only regions covered by lists
  if(suit_geo){
    list_set <- list_set[which(list_set$suit_geo == "1"), ]
  }
  
  # Add full taxonomic names
  list_set <- dplyr::left_join(list_set, taxonomy, by = "taxon_ID")
  
  # Whether regions cover entirely or not the required taxonomic group
  if(complete_taxon){
    range_taxgroup <- taxonomy[which(taxonomy$taxon_ID == tax_group), "rgt"] -
      taxonomy[which(taxonomy$taxon_ID == tax_group), "lft"]
    
    list_set <- dplyr::mutate(list_set, range_covered = rgt - lft)
    list_set <- dplyr::group_by(list_set, entity_ID)
    list_set <- dplyr::mutate(list_set, range_covered_max = max(range_covered))
    list_set <- dplyr::ungroup(list_set)
    list_set <- dplyr::filter(list_set, range_covered_max >= range_taxgroup)
    list_set <- as.data.frame(list_set)
    
    # Remove unnecessary columns
    list_set <- dplyr::select(list_set, -range_covered, -range_covered_max)
    
    # TO DO: allow for cases when you can "sum" for taxonomic subsets
    # TO DO account for cases in which we don't have a list for a taxonomic
    # group but for all subgroups included
  }
  
  # Remove unnecessary columns from join with taxonomy
  list_set <- dplyr::select(list_set, -taxon_author, -taxon_lvl, -lft, -rgt)
  
  list_set <- dplyr::mutate_at(
    list_set, c("ref_ID","native_indicated","natural_indicated","end_ref",
                "restricted","taxon_ID","list_ID","end_list","entity_ID",      
                "suit_geo"), as.numeric)
  
  # Output
  return(list_set)
}

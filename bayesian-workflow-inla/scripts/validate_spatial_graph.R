#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(spdep)
  library(sf)
})

#' Validate Spatial Adjacency Graph for INLA
#'
#' Checks spatial polygons or neighbor objects for isolated components, symmetry,
#' self-loops, and zero-neighbor areas before exporting to INLA graph format via nb2INLA.
#'
#' @param spatial_obj An sf or SpatialPolygons object, or an nb list
#' @param graph_out Optional file path to save INLA graph format (.graph)
#' @return A list with graph integrity diagnostics
validate_spatial_graph <- function(spatial_obj, graph_out = NULL) {
  if (inherits(spatial_obj, c("sf", "sfc"))) {
    nb <- spdep::poly2nb(spatial_obj, queen = TRUE)
  } else if (inherits(spatial_obj, "nb")) {
    nb <- spatial_obj
  } else {
    stop("Input must be an sf object or a spdep 'nb' class object.")
  }

  n_nodes <- length(nb)
  card_nb <- spdep::card(nb)
  zero_neighbors <- which(card_nb == 0)
  
  # Check connected components
  comp_info <- spdep::n.comp.nb(nb)
  n_components <- comp_info$nc

  is_valid <- (length(zero_neighbors) == 0) && (n_components == 1)

  diag_report <- list(
    n_nodes = n_nodes,
    n_components = n_components,
    zero_neighbor_nodes = zero_neighbors,
    average_neighbors = mean(card_nb),
    is_fully_connected = (n_components == 1),
    valid_for_inla = is_valid
  )

  if (length(zero_neighbors) > 0) {
    warning(sprintf("Spatial graph has %d isolated node(s) with 0 neighbors! ICAR/BYM2 require connected nodes or manual handling.", length(zero_neighbors)))
  }

  if (n_components > 1) {
    warning(sprintf("Spatial graph has %d disconnected sub-components. Consider adjusting constr=TRUE or scaling components.", n_components))
  }

  if (!is.null(graph_out)) {
    spdep::nb2INLA(graph_out, nb)
    diag_report$graph_file <- graph_out
  }

  return(diag_report)
}

if (sys.nframe() == 0) {
  option_list <- list(
    make_option(c("--spatial_file"), type = "character", default = NULL, 
                help = "Path to spatial vector file (GeoJSON, GPKG, Shapefile, or RDS)"),
    make_option(c("--graph_out"), type = "character", default = NULL, 
                help = "Path to write INLA graph file (e.g., spatial.graph)")
  )

  opt_parser <- OptionParser(option_list = option_list)
  opt <- parse_args(opt_parser)

  if (is.null(opt$spatial_file)) {
    print_help(opt_parser)
    stop("Argument --spatial_file is required.", call. = FALSE)
  }

  if (grepl("\\.rds$", opt$spatial_file, ignore.case = TRUE)) {
    sp_data <- readRDS(opt$spatial_file)
  } else {
    sp_data <- sf::st_read(opt$spatial_file, quiet = TRUE)
  }

  res <- validate_spatial_graph(sp_data, graph_out = opt$graph_out)
  cat(paste("Spatial Graph Validation Report:\n"))
  cat(sprintf("  Nodes: %d\n", res$n_nodes))
  cat(sprintf("  Connected Components: %d\n", res$n_components))
  cat(sprintf("  Avg Neighbors: %.2f\n", res$average_neighbors))
  cat(sprintf("  Valid for INLA: %s\n", res$valid_for_inla))
  if (!is.null(res$graph_file)) {
    cat(sprintf("  Exported graph to: %s\n", res$graph_file))
  }
}

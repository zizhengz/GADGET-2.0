#---------------------------------------------------------------------------------------------------
# GENERAL HELPER FUNCTIONS
#---------------------------------------------------------------------------------------------------

#' Print summary of split criteria in a partition tree
#'
#' @param tree A list of tree nodes structured by depth,
#' @param feat_name Character string specifying a single feature name to filter the
#'   displayed heterogeneity (`objective.value`).
#'
#' @return No return value. The function prints to console.
#'
#' @export
extract_split_criteria = function(tree, feat_name = NULL) {
  cat_line = function(...) cat(paste0(..., "\n"))

  if (is.null(feat_name)) {
    cat_line("🌳 Full Tree Structure:")
  } else {
    cat_line(sprintf("Feature %s - 🌳 Full partition tree:", feat_name))
  }
  cat_line(strrep("─", 40))

  all_nodes = unlist(tree, recursive = FALSE)
  all_nodes = Filter(Negate(is.null), all_nodes)
  node_map = setNames(all_nodes, vapply(all_nodes, function(n) as.character(n$id), character(1)))

  print_node = function(node, prefix = "") {
    if (is.null(node)) {
      return()
    }

    heter_vec = unlist(node$objective.value, recursive = TRUE, use.names = TRUE)
    heter_strs = if (!is.null(heter_vec)) {
      if (!is.null(feat_name) && feat_name %in% names(heter_vec)) {
        paste0(feat_name, ".heter: ", formatC(heter_vec[feat_name], format = "f", digits = 2))
      } else {
        paste0(names(heter_vec), ".heter: ", formatC(heter_vec, format = "f", digits = 2))
      }
    } else {
      "heter: NA"
    }
    inst = if (!is.null(node$subset.idx)) length(node$subset.idx) else NA_integer_
    intImp = if (!is.null(node$intImp) && is.numeric(node$intImp)) round(node$intImp, 3) else NULL

    conds = c()
    current = node
    while (!is.null(current$id.parent)) {
      parent = node_map[[as.character(current$id.parent)]]
      if (is.null(parent)) break
      is_left = !is.null(parent$children[[1]]) && identical(parent$children[[1]], current)
      op = if (is_left) {
        if (is.numeric(parent$split.value)) "≤" else "="
      } else {
        if (is.numeric(parent$split.value)) ">" else "≠"
      }
      cond = paste0(parent$split.feature, " ", op, " ", round(as.numeric(parent$split.value), 3))
      conds = c(cond, conds)
      current = parent
    }

    split_expr = if (length(conds) > 0) paste(paste(conds, collapse = " & "), " ") else ""
    show_intImp = !(isTRUE(node$improvement.met) | isTRUE(node$stop.criterion.met) | node$depth == length(tree))

    fields = c(
      paste0("depth: ", node$depth),
      paste0("id: ", node$id),
      if (!is.null(intImp) && show_intImp) paste0("intImp: ", formatC(intImp, format = "f", digits = 3)) else NULL,
      heter_strs,
      if (!is.na(inst)) paste0("# inst: ", inst) else NULL
    )

    if (nzchar(split_expr)) {
      cat_line(prefix, paste0("✂️ ", split_expr))
    }
    cat_line(prefix, "[", paste(fields, collapse = " | "), "]")


    # if (is.null(node$children) || (is.null(node$children[[1]]) && is.null(node$children[[2]]))) {
    #   cat_line(prefix, "    🌿 Leaf Node")
    # } else {
    #   print_node(node$children[[1]], paste0(prefix, "    "))
    #   print_node(node$children[[2]], paste0(prefix, "    "))
    # }
    if (!is.list(node$children) || length(node$children) < 2 ||
      (is.null(node$children[[1]]) && is.null(node$children[[2]]))) {
      cat_line(prefix, "    🌿 Leaf Node")
    } else {
      if (!is.null(node$children[[1]])) print_node(node$children[[1]], paste0(prefix, "    "))
      if (!is.null(node$children[[2]])) print_node(node$children[[2]], paste0(prefix, "    "))
    }

  }

  print_node(tree[[1]][[1]])
  invisible(NULL)
}

# extract_split_criteria1 = function(tree) {
#
#   list.split.criteria = lapply(tree, function(depth) {
#     lapply(depth, function(node) {
#
#       if (is.null(node)) {
#         df = NULL
#       } else if (node$improvement.met | node$stop.criterion.met | node$depth == length(tree)) {
#         df = data.frame("depth" = node$depth, "id" = node$id,
#           "objective.value" = node$objective.value,
#           "objective.value.parent" = node$objective.value.parent,
#           "intImp" = NA,
#           "intImp.parent" = NA,
#           "split.feature" = "final",
#           "split.value" = NA,
#           "split.feature.parent" = node$split.feature.parent,
#           "node.final" = TRUE)
#       } else {
#         df = data.frame("depth" = node$depth, "id" = node$id,
#           "objective.value" = node$objective.value,
#           "objective.value.parent" = node$objective.value.parent,
#           "intImp" = node$intImp,
#           "intImp.parent" = node$intImp.parent,
#           "split.feature" = node$split.feature,
#           "split.value" = node$split.value,
#           "split.feature.parent" = node$split.feature.parent,
#           "node.final" = FALSE)
#       }
#       df
#     })
#   })
#   # list.split.criteria = list.clean(list.split.criteria, function(x) length(x) == 0L, TRUE)
#   list.split.criteria = Filter(function(x) length(x) > 0L, list.split.criteria)
#   df.split.criteria = unlist(list.split.criteria, recursive = FALSE)
#   df.split.criteria = as.data.frame(do.call(rbind, df.split.criteria))
#   n.final = length(which(df.split.criteria$node.final == TRUE))
#   df.split.criteria$n.final = n.final
#
#
#   return(df.split.criteria)
# }


#' L2 (sum-of-squares) objective
#'
#' @param y A \code{list} of numeric matrices / data.frames.
#' @param x Ignored (kept for a uniform objective-function interface).
#' @param requires.x Logical; always \code{FALSE} here.
#' @param ... Further arguments (currently unused).
#'
#' @return A \code{list} of numeric scalars: the L2 loss for each
#'   element of \code{y}.
#'
#' @keywords internal
SS_L2 = function(y, x, requires.x = FALSE, ...) {
  L2 = lapply(y, function(feat) {
    # y_sub = feat[,setdiff(colnames(y), c("type",".id",".feature"))]
    ypred = colMeans(as.matrix(feat), na.rm = TRUE)
    sum(t((t(feat) - ypred)^2), na.rm = TRUE)
  })
  L2
}


#' ALE stability objective (sum-of-squares)
#'
#' @inheritParams SS_L2
#' @param split.feat Character string: the feature that is currently
#'   considered for splitting
#'
#' @return A \code{list} of numeric scalars: the ALE L² loss per
#'   element of \code{y}.
#'
#' @keywords internal
SS_ALE = function(y, x, split.feat, requires.x = FALSE, ...) {
  L2 = lapply(y, function(feat) {
    delta.aggr = feat[, list(dL = mean(dL, na.rm = TRUE),
      interval.n = .N), by = c("interval.index", "x.left", "x.right")]

    df = merge(feat, delta.aggr, by = "interval.index")
    sum(((df$dL.x - df$dL.y)^2), na.rm = TRUE)
  })
  L2
}


#' SHAP objective
#'
#' Fits a cubic regression spline to SHAP values via
#' \code{mgcv::gam()} and returns the residual sum-of-squares (RSS).
#'
#' @inheritParams SS_ALE
#'
#' @return A \code{list} of numeric scalars: the RSS for each element
#'   of \code{y}.
#'
#' @importFrom mgcv gam
#'
#' @keywords internal
SS_SHAP = function(y, x, split.feat, requires.x = FALSE, ...) {
  L2 = lapply(y, function(feat) {
    gam_mod = mgcv::gam(phi ~ s(feat.val, k = 3), data = feat)
    sum(gam_mod$residuals^2, na.rm = TRUE)
  })
  L2
}

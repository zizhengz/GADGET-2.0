% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/helper_tree_splitting.R
\name{get_closest_point}
\alias{get_closest_point}
\title{Map candidate split points to the nearest admissible values}
\usage{
get_closest_point(split.points, xval, min.node.size = 10)
}
\arguments{
\item{split.points}{Numeric vector of preliminary candidate cut
points (e.g., quantiles or mid‐points).}

\item{xval}{Numeric vector of the feature values in the parent node.}

\item{min.node.size}{Integer. Minimum number of observations each
child node must preserve.}
}
\value{
Numeric vector of the same length as \code{split.points}
  containing adjusted split locations.
}
\description{
Map candidate split points to the nearest admissible values
}
\keyword{internal}

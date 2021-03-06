#' Fetch tile region.
#'
#' Given bounding box, find tiles that span region and stitch them together
#' into a single raster.
#'
#' @param lon,lat Longitude and latitiude ranges
#' @param provider A tile set provider. See \code{\link{providers}}
#'   for possible options
#' @param cache If \code{TRUE}, uses cache as described in
#'   \code{\link{cache_path}}
#' @param zoom Zoom level (0-18). Higher numbers produce more detailed
#'   graphics, but will require more data to be downloaded.
#' @export
#' @examples
#' houston <- fetch_region(c(-95.80204, -94.92313), c(29.38048, 30.14344),
#'   stamen("terrain"))
#' houston
#' plot(houston)
fetch_region <- function(lon, lat, provider, cache = TRUE, zoom = 10) {
  meta <- bbox_tiles(lon, lat, zoom = zoom)
  meta$url <- provider$tile_f(meta$x, meta$y, meta$z)
  tiles <- lapply(meta$url, fetch_tile, cache = cache)

  region <- stitch_tiles(meta, tiles)

  # Compute pixel coordinates
  x <- lon2x(range(lon), zoom)
  l <- x$x[1] + 1
  r <- diff(x$X) * 256 + x$x[2] + 1

  y <- lat2y(rev(range(lat)), zoom)
  b <- y$y[1] + 1
  t <- diff(y$Y) * 256 + y$y[2] + 1

  # Crop & save bounding box
  clipped <- region[b:t, l:r]
  class(clipped) <- c("rastermap", "raster")
  attr(clipped, "bb") <- bbox(lon, lat)
  clipped
}

bbox_tiles <- function(lon, lat, zoom = 10) {
  lon <- range(lon, na.rm = TRUE)
  lat <- range(lat, na.rm = TRUE)

  br <- lonlat2xy(lon[1], lat[1], zoom)
  tl <- lonlat2xy(lon[2], lat[2], zoom)

  xs <- seq(br$X, tl$X)
  ys <- seq(br$Y, tl$Y)

  tiles <- expand.grid(y = ys, x = xs, KEEP.OUT.ATTRS = FALSE)
  tiles$z <- zoom
  tiles
}

fetch_tile <- function(url, cache = TRUE, quiet = FALSE) {
  tile <- cache_get(url)
  if (!is.null(tile) && cache) return(tile)

  if (!quiet)
    message("Fetching ", url)
  r <- httr::GET(url)
  httr::stop_for_status(r)

  tile <- httr::content(r, "parsed")
  tile <- t(apply(tile, 2, rgb))
  attr(tile, "url") <- url
  class(tile) <- c("ggmap", "raster")
  if (cache) {
    cache_set(url, tile)
  }
  tile
}

stitch_tiles <- function(meta, tiles) {
  stopifnot(length(tiles) == nrow(meta))

  w <- length(unique(meta$x))
  h <- length(unique(meta$y))

  out <- matrix(NA_character_, w * 256, h * 256)

  xs <- (match(meta$x, sort(unique(meta$x))) - 1) * 256
  ys <- (match(meta$y, sort(unique(meta$y))) - 1) * 256

  for (i in seq_along(tiles)) {
    out[xs[i]:(xs[i] + 255) + 1, ys[i]:(ys[i] + 255) + 1] <- tiles[[i]]
  }
  class(out) <- c("tile", "raster")

  dim(out) <- rev(dim(out))
  out
}


bbox <- function(lon, lat) {
  data.frame(
    ll.lat = min(lat),
    ll.lon = min(lon),
    ur.lat = max(lat),
    ur.lon = max(lon)
  )
}

#' @export
print.rastermap <- function(x, ...) {
  cat("<rastermap>\n")

  bb <- unlist(format(attr(x, "bb"), digits = 4))
  cat("  Lat: ", bb[1], " - ", bb[3], " (", nrow(x), " px)\n", sep = "")
  cat("  Lon: ", bb[2], " - ", bb[4], " (", ncol(x), " px)\n", sep = "")
}


# Called indirectly by httr::content - added here to silence R CMD check NOTE
#' @importFrom png readPNG
#' @importFrom jpeg readJPEG
NULL

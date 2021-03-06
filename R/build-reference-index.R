data_reference_index <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  meta <- pkg$meta[["reference"]] %||% default_reference_index(pkg)
  if (length(meta) == 0) {
    return(list())
  }

  sections <- meta %>%
    purrr::map(data_reference_index_section, pkg = pkg) %>%
    purrr::compact()

  # Cross-reference complete list of topics vs. topics found in index page
  all_topics <- meta %>%
    purrr::map(~ select_topics(.$contents, pkg$topics)) %>%
    purrr::reduce(union)
  in_index <- seq_along(pkg$topics$name) %in% all_topics

  missing <- !in_index & !pkg$topics$internal
  if (any(missing)) {
    warning(
      "Topics missing from index: ",
      paste(pkg$topics$name[missing], collapse = ", "),
      call. =  FALSE,
      immediate. = TRUE
    )
  }

  icons <- sections %>% purrr::map("contents") %>% purrr::flatten() %>% purrr::map("icon")

  print_yaml(list(
    pagetitle = "Function reference",
    sections = sections,
    has_icons = purrr::some(icons, ~ !is.null(.x))
  ))
}

data_reference_index_section <- function(section, pkg) {
  if (!set_contains(names(section), c("title", "contents"))) {
    warning(
      "Section must have components `title`, `contents`",
      call. = FALSE,
      immediate. = TRUE
    )
    return(NULL)
  }

  # Find topics in this section
  in_section <- select_topics(section$contents, pkg$topics)
  section_topics <- pkg$topics[in_section, ]

  contents <- tibble::tibble(
    path = section_topics$file_out,
    aliases = purrr::map2(
      section_topics$funs,
      section_topics$name,
      ~ if (length(.x) > 0) .x else .y
    ),
    title = section_topics$title,
    icon = find_icons(section_topics$alias, path(pkg$src_path, "icons"))
  )
  list(
    title = section$title,
    slug = paste0("section-", make_slug(section$title)),
    desc = markdown_text(section$desc),
    class = section$class,
    contents = purrr::transpose(contents)
  )
}


find_icons <- function(x, path) {
  purrr::map(x, find_icon, path = path)
}
find_icon <- function(aliases, path) {
  names <- paste0(aliases, ".png")
  exists <- file_exists(path(path, names))

  if (!any(exists)) {
    NULL
  } else {
    names[which(exists)[1]]
  }
}

default_reference_index <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  exported <- pkg$topics[!pkg$topics$internal, , drop = FALSE]
  if (nrow(exported) == 0) {
    return(list())
  }

  print_yaml(list(
    list(
      title = "All functions",
      desc = NULL,
      contents = paste0('`', exported$name, '`')
    )
  ))
}

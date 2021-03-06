#' Make a local directory into a Git repository that tracks a remote
#'
#' Take a local project, put it under version control if necessary, optionally
#' make it an RStudio Project, create a companion repository on GitHub, connect
#' them, and, if in an interactive session, visit the new repo in the browser.
#' Inspired by \code{hub create} from the \href{https://hub.github.com}{hub}
#' command line tool.
#'
#' This requires a free GitHub account, which can be registered at
#' \url{https://github.com}. There is some additional setup that gives
#' \code{\link{githug}} the ability to deal with GitHub on your behalf:
#'
#' \describe{
#' \item{GitHub personal access token}{The only way to create a GitHub
#' repository is through the API, so you must obtain a personal access token
#' (PAT). For advice on how to store your PAT, see \code{\link{gh_pat}()}.}
#' \item{GitHub username}{\code{githug_init()} uses your PAT to lookup your
#' GitHub username. This information, and much more, is stored in custom Git
#' variables for downstream use. The GitHub username is stored under
#' \code{githug.username} and can be configured globally, i.e. at the user
#' level, or locally, i.e. at the repo level (the default and automatic behavior
#' of \code{githug_init()}). To set or modify \code{githug.username} manually,
#' use \code{git_config_global(githug.username = <YOUR-GITHUB-USERNAME>)} or
#' \code{git_config_local(githug.username = <YOUR-GITHUB-USERNAME>)}.} }
#'
#' At the moment, \code{githug_init()} is designed only to create a new GitHub
#' repo, though that should change. Currently, the function just stops if it
#' detects evidence of a pre-existing remote/GitHub setup. Temporary
#' workarounds:
#'
#' \itemize{
#' \item If the local repo is valuable and the GitHub remote is expendable,
#' delete the GitHub repo. For now, do that in the browser. Also delete the
#' \code{origin} remote from the local repository, via
#' \code{git2r::remote_remove(as_git_repository(), "origin")} in R or \code{git
#' remote rm origin} in the shell. And call \code{githug_init()} again.
#' \item If the GitHub repo is valuable and the local repo is expendable, delete
#' local. And use `git clone` or RStudio to clone the GitHub repo. \item If both
#' are valuable, \code{githug} can't help you yet. }
#'
#' Credentials. Most people (?) should not need to use \code{cred} unless they
#' want to. For "https" users, \code{githug_init} uses your PAT to push. For
#' "ssh" users, it is assumed that public and private keys are in the default
#' locations, \code{~/.ssh/id_rsa.pub} and \code{~/.ssh/id_rsa}, respectively,
#' and that \code{ssh-agent} is configured to manage any associated passphrase.
#' If you want to specify credentials explicitly, see
#' \code{\link[git2r]{cred_ssh_key}}, \code{\link[git2r]{cred_user_pass}},
#' \code{\link[git2r]{cred_env}}, and \code{\link[git2r]{cred_token}}.
#'
#' @param name Name of the new repository, optional. Default behavior if
#'   unspecified: if an RStudio project file is found in \code{path},
#'   \code{name} will be the filename, after removing the \code{.Rproj}
#'   extension. Otherwise, \code{name} will be the \code{\link{basename}()} of
#'   \code{path}.
#' @param description Short description of the GitHub repository, optional.
#' @param remote_name Name for the new GitHub remote, optional. Defaults to
#'   \code{origin}.
#' @param protocol Transfer protocol, either "https" (the default) or "ssh".
#' @param cred Credential object, in the sense of the \code{\link{git2r}}
#'   package, optional. If you are already able to push and pull from the
#'   command line, you can probably ignore this. See details for more.
#' @param pat A GitHub personal access token (PAT) from
#'   \url{https://github.com/settings/tokens}.  The "repo" scope is required
#'   which is one of the default scopes for a new PAT. By default, \code{pat}
#'   will be obtained via \code{\link{gh_pat}()}, which consults your
#'   environment variables (by default, \code{GITHUB_PAT} and
#'   \code{GITHUB_TOKEN}, in that order).
#' @param path Path to the directory where a Git repo should be initialized, if
#'   not done already, and connected to GitHub, optional. Defaults to working
#'   directory.
#' @param rstudio Logical indicating whether to ensure repo directory is also an
#'   \href{https://support.rstudio.com/hc/en-us/articles/200526207-Using-Projects}{RStudio
#'    Project}
#' @param ... Other parameters passed to the GitHub API when creating the new
#'   repository, optional. Read more at
#'   \url{https://developer.github.com/v3/repos/#create}. For example, by
#'   passing \code{private = TRUE}, you can create a new private repository, if
#'   your GitHub account is eligible.
#'
#' @return Path to the local repository.
#' @export
#' @examples
#' \dontrun{
#' ## Example 1:

#' ## create a directory and local repo and RStudio project and remote repo, all
#' at once
#' ## TO DO: remove private = TRUE maybe
#'
#' githug_init(path = tempfile("init-test-"), private = TRUE)
#' }
#'
#' \dontrun{
#' ## Example 2:
#' ## connect a pre-existing Git repo to GitHub
#' repo <- git_init(tempfile("githug-init-example-"))
#'
#' ## switch working directory to the repo
#' owd <- setwd(repo)
#'
#' ## Config local git user and make a commit
#' git_config(user.name = "thelma", user.email = "thelma@example.org")
#' writeLines("I don't ever remember feeling this awake.", "thelma.txt")
#' git_COMMIT("thelma is awake")
#' git_log()
#'
#' ## Connect it to GitHub! Visit the new repo in the browser.
#' ## TO DO: remove private = TRUE maybe
#' githug_init(private = TRUE)
#'
#' ## see that the 'origin' is now set to the GitHub remote
#' ## TO DO: revise this when remote stuff done
#' git2r::remotes()
#' git2r::remote_url(as_git_repository())
#'
#' ## see that local master is tracking remote master
#' git2r::branch_get_upstream(git_HEAD()$git_branch)
#'
#' setwd(owd)
#' }
#'
#' \dontrun{
#' ## Example 3:
#' ## Turn an existing directory into a Git repo to and connect to GitHub
#' repo <- tempfile("githug-init-example-")
#' dir.create(repo)
#' owd <- setwd(repo)
#' ## TO DO:remove private = TRUE maybe
#' githug_init(private = TRUE)
#' setwd(owd)
#' }
githug_init <- function(
  path = ".",
  name = NULL,
  description = NULL,
  remote_name = "origin",
  protocol = c("https", "ssh"), cred = NULL, pat = gh_pat(),
  rstudio = TRUE,
  ...) {

  gh_username <- gh_username(pat = pat)
  message("GitHub username: ", gh_username)

  protocol <- match.arg(protocol)
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)

  repo <- git_init(path = path, force = FALSE)
  if (wd_is_dirty(repo = repo)) git_COMMIT("init", repo = repo)

  name <- name %||% githug_name(path = repo)
  message("Name of dir / RStudio Project / GitHub repo: ", name)

  ## based on devtools::use_rstudio()
  if (rstudio && !is_a_rsp(repo)) {
    message("Adding RStudio project file to ", repo)
    template <- system.file("templates/template.Rproj", package = "githug")
    rproj <- file.path(repo, paste0(name, ".Rproj"))
    file.copy(template, rproj)
    message("Gitignoring standard R/RStudio files")
    ## .Rhistory and .RData are not specific to RStudio; is this logical?
    gitignore <- git_ignore(c(".Rproj.user", ".Rhistory", ".RData"), repo)
    git_add(c(gitignore, rproj), repo = repo)
    git_commit("rstudio init", repo = repo)
  }

  message("Storing GitHub username '", gh_username, "' to local git config var")
  git_config_local(githug.user = gh_username, repo = repo)

  description <- description %||% "R work of staggering genius"

  readme_path <-
    githug_README(path = repo, name = name, description = description)

  if (wd_is_dirty(repo)) {
    git_add(readme_path, repo = repo)
    git_commit("add README.md", repo = repo)
  }

  ## TO DO: move into a function that creates a df about remotes
  remote_urls <- function(repo) {
    r <- as_git_repository(repo)
    remotes <- git2r::remotes(r)
    stats::setNames(git2r::remote_url(r, remotes), remotes)
  }
  remotes <- remote_urls(repo = as_git_repository(path))

  if (length(remotes)) {
    stop("Oops. We're not quite ready to handle a repo with an existing",
         "remote. Read the help for advice in the meantime.", call. = FALSE)
  }

  user_repos <- repo_list_pat(pat = pat, affiliation = "owner")
  user_repo_names <- purrr::map_chr(user_repos, "name")
  if (name %in% user_repo_names) {
    stop("You already own a repository named '", name, "'.\n",
         "Read the help for githug_init() for next steps.", call. = FALSE)
  }

  ## this should be a separate function
  message("Creating GitHub repo:\n",
          "  name = ", name, "\n",
          "  description = ", ellipsize(description), "\n")
  ret <- gh::gh("POST /user/repos", name = name, description = description,
                .token = pat, ...)

  ## extract info to stow in local githug custom git vars
  message("Storing GitHub repo info to local git config")
  githug_config <- get("githug_config", envir = .githug)
  githug_config_vars <- stats::setNames(ret[githug_config], githug_config)
  githug_config_vars$protocol <- protocol
  githug_config_vars$remote_name <- remote_name
  githug_config_vars <- githug_config_vars %>%
    purrr::compact() %>%
    purrr::map(as.character)
  names(githug_config_vars) <-
    names(githug_config_vars) %>%
    gsub("_", "", .) %>%
    paste("githug", . , sep = ".")
  git_config_local(githug_config_vars, repo = repo)

  ## NOTE: custom git var names now prefixed with 'githug.' and underscores are
  ## gone!
  push_url <- switch(githug_config_vars$githug.protocol,
                     https = githug_config_vars$githug.cloneurl,
                     ssh = githug_config_vars$githug.sshurl)
  git2r::remote_add(repo = as_git_repository(path),
                    name = githug_config_vars$githug.remotename,
                    url = push_url)
  message("Adding remote named '", githug_config_vars$githug.remotename,
          "':\n  ", push_url)

  if (protocol == "https") {
    ## do people really need to know this?
    # if (is.null(cred)) {
    #   message("Protocol requested is 'https', so credentials in 'cred' will ",
    #           "not be used here. Pushing with 'pat'.")
    # }
    ## you'd expect to use gitr::cred_token() but it expects env var names
    ## and we've already got the pat
    cred <- git2r::cred_user_pass("USERNAME", pat)
  }

  message("Pushing to GitHub and setting remote tracking branch")
  git2r::push(object = as_git_repository(path),
              name = githug_config_vars$githug.remotename,
              refspec = "refs/heads/master",
              credentials = cred)
  git2r::branch_set_upstream(git_HEAD(path)$git_branch, "origin/master")

  ## is this terribly annoying?
  ## regardless, it should be it's own function ... nod to `hub browse`
  if (interactive())
    browseURL(githug_config_vars$githug.htmlurl)

  invisible(repo)

}

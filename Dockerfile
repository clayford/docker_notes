# use rocker image
FROM rocker/rstudio:4.5.0

# install the {renv} package
RUN install2.r --error renv \
    && rm -rf /tmp/downloaded_packages

# set working directory
WORKDIR /home/rstudio/research_project

# copy in files
COPY mpg.rds mpg.rds
COPY analysis.R analysis.R
COPY renv.lock renv.lock

# tell {renv} which library paths to use for package installation
ENV RENV_PATHS_LIBRARY=renv/library

# restore packages as defined in the lockfile
RUN R -e "renv::restore()"

# Notes on using Docker on a Windows machine

May 16, 2025

I think the best way to use Docker on a Windows machine is to install Windows Subsystem for Linux and then use Docker there. 

How to install Windows Subsystem for Linux (WSL):   
<https://learn.microsoft.com/en-us/windows/wsl/install>.   
Requires Windows 10 version 2004 and higher or Windows 11.

Next install Docker for WSL. The following instructions worked for me in May 2025:   
<https://docs.docker.com/engine/install/ubuntu/>

## Two primary uses for Docker:

1. As a container for research (consistent version of OS, R, and R packages). Perhaps for a team who need to work in the same environment.
2. As a container to preserve and share research for reproducibility. Perhaps for a paper that has been published. 

### Container for Research

This is pretty easy once you have Docker installed. Just follow instructions on the [Rocker Project Home Page](https://rocker-project.org/).

Below is a modified command that maps a local folder to a folder inside the container that allows us to save our work. You can change the password.

```
docker run --rm -ti -v ~/test_project:/home/rstudio/project -e PASSWORD=clay -p 8787:8787 rocker/rstudio:4.5.0
```

Then go to <http://localhost:8787/> in your browser to use RStudio. You login with username "rstudio" and whatever password you specified in the `docker run` command. 

Save work to the "project" folder. When done, close RStudio and hit Ctrl + C in the terminal on your local machine to close Docker. Any work you saved into the "project" folder in the container will be available in the "test_project" folder. 

About the `docker run` options:

- `--rm` automatically removes the container when it exits
- `-ti` (or `-it`) is actually a combination of two separate Docker flags:
    * -t (or --tty): Allocates a pseudo-TTY or terminal. This simulates a real terminal like what you'd get when using an interactive shell.
    * -i (or --interactive): Keeps STDIN open even if not attached. This allows you to provide input to the container.
- `-e` sets an environment variable
- `-v` mounts a volume from host to container
- `-p` maps a port from host to container

Without the `--rm` option the contain is saved after you exit. You can restart the container using `docker start` along with the specific hash of the container, which can be found using `docker ps`. For example:

`docker start -ai 4313a3f3f11d`

Let's say you install packages and want them to be there the next time you start the container. You need to save the image by running `docker commit`. To do this you need to open another terminal window before you close the Docker container. Example:

```
docker commit -m "installed emmeans" <hash> new_image_name
```

`<hash>` is the specific hash of the _currently_ running container. It will look something like 4a6a528b35da.

Next time, do the following to run the container:

```
docker run --rm -ti -v ~/test_project:/home/rstudio/project -e PASSWORD=clay -p 8787:8787 new_image_name
```

Some [tutorials](https://jsta.github.io/r-docker-tutorial/05-dockerfiles.html) frown on using `docker commit` to update images. They say a Dockerfile should be created to document how the image was created. Recall Dockerfiles are used to build images. Images are then used to run containers. 

You would first write a Dockerfile, and then use the Dockerfile to create an image, and then use the image to create a container. The image could be uploaded to Docker Hub and shared with others. 

Example of a Dockerfile that installs two R packages and includes a data file. A Dockerfile is a text file with instructions for building an image.

The `install2.r` command can be used to concisely describe the installation of the R package. `install2.r` is included with Rocker images.

```
# use rocker image
FROM rocker/rstudio:4.5.0

# install R packages
RUN install2.r --error emmeans lme4 \
    && rm -rf /tmp/downloaded_packages

# copy in a data set; assumes data is in same directory as Dockerfile
COPY warpbreaks.rds home/rstudio/warpbreaks.rds
```

Then `cd` into the directory with the Dockerfile and build the image using `docker build`. The `-t` option allows you tag the image during the build. `[username]` is your Docker Hub user name, `[image_name]` is the image name, and `[tag]` is the tag.

```
docker build . -t [username]/[image_name]:[tag]
```

For example, I might run the following where I tag the image as v1.

```
docker build . -t clayford/rstudio_image:v1
```

This can take some time if packages have to be compiled. 

If I would like to share this image, I could push to Docker Hub using `docker push`. First I would need to authenticate using `docker login`. You'll be promtped to enter your Docker Hub user name and password. If you don't have one, sign up for free at [Docker Hub](https://hub.docker.com/).

```
docker login
docker push clayford/rstudio_image
```

Now anyone can download and run the same exact computational environment as me.

```
docker run --rm -ti -v ~/test_project:/home/rstudio/project -e PASSWORD=pwd -p 8787:8787 clayford/rstudio_image:v1
```

### Container for Reproducibility

Let's say you've published some research (or taught a workshop, or have given a presentation) and you want to share your code and data with anyone who might want to replicate your analysis. Docker allows you to share your exact operating system, version of R, and specific R packages you used to perform your analysis, as well as your code and data. It's kind of a like a time machine where someone can travel back in time and run the analysis just as you did on your computer. 

The idea is to build an image and then push it to Docker Hub. Then if anyone wanted to replicate your analysis, they could pull the image and run the container. You can run the steps above to build an image. There's nothing different except you would want to include your code along with your data. That would require extra `COPY` statements in the Dockerfile. In fact you don't really need to use a Dockerfile. You could just start a container using a Rocker image, install the R packages you need, load your code and data, and use `docker commit` to update and save the image. Done.

However you might want to create a Dockerfile so someone else (including your future self) could see how the image was created. The tricky part is that you would NOT want to include something like this in the Dockerfile:

```
RUN install2.r --error emmeans lme4 \
    && rm -rf /tmp/downloaded_packages
```

Anyone using your Dockerfile to build a new image would get the _latest versions_ of the R packages, which may be different than the versions you used to initially create the image. Imagine someone (including yourself) using your Dockerfile five years after you published some research to re-build the image. They're almost certainly going to get newer versions of the R packages you used, especially if the packages are actively maintained. 

To prevent this from happening, you need to specify the _specific versions_ of the R packages you used. One way to do this is to use the {renv} package. This [vignette](https://cran.r-project.org/web/packages/renv/vignettes/renv.html) explains the {renv} package. Here's the key quote: 

> ...renv gives you a separate library for each project. This gives you the benefits of isolation: different projects can use different versions of packages, and installing, updating, or removing packages in one project doesn’t affect any other project."

The {renv} package creates something called a "lockfile", which is named "renv.lock". This file records metadata about every package that your project is using and allows someone to re-install the same packages on a new machine. We can use this lockfile in our Dockerfile to specify which versions of R packages we want to use. 

The way you use {renv} locally is as follows:

1. Install the {renv} package.
2. Start a new RStudio project in a new directory and check the box "Use renv with this project". Or open an existing project and run `renv::init()`
3. Go to the packages tab. Notice you only have the base R recommended packages. Install the packages you need to do your analysis. 
4. After installing the packages (and checking that your code works), call `renv::snapshot()` to record the latest package versions in your lockfile. **Beware**: For a package to be recorded in the lockfile, it must be both installed in your project library and _used by the project_. If you want to capture all packages installed into your project library regardless of whether they're currently used in any R scripts, run `renv::settings$snapshot.type("all")` and then run `renv::snapshot()`.

See the [Introduction to renv](https://rstudio.github.io/renv/articles/renv.html) for how collaborators can use your lockfile to recreate the same package environment by running `renv::restore()`. Since this is about Docker, I'm skipping to the part where we use the lockfile in a Dockerfile.

Let's say you've done the following:

1. Started a new Rocker container using R version 4.5.0 as follows and saved all work in a folder called "research_project" using the following command: `docker run --rm -ti -v ~/research_project:/home/rstudio/research_project -e PASSWORD=clay -p 8787:8787 rocker/rstudio:4.5.0`
2. While in the container you installed the {renv} package and initialized the project to use {renv} by running `renv::init()`
3. You also installed the {ggplot2} package which installed a number of dependencies.
4. You created an R script called "analysis.R" in which you did your research. The R script loads a data set named "mpg.rds".
5. You ran `renv::snapshot()` to capture the specific versions of the packages you used.
6. You published a paper or presented your research and now you want provide a Docker image with all code and data so someone (possibly your future self) can replicate this analysis using the exact same computing environment as you. 

You could use `docker commit` to update and save the image, but you want to create a Dockerfile so you have a record of how you created the image.

Here is one such Dockerfile. Create the Dockerfile from the command line by running `nano Dockerfle` and then copying and pasting in the following. It helps to save the Dockerfile to your project directory. I have made this very simple by only using two files and saving everything in one folder. If your analysis has multiple sub-folders with parts of your analysis, you would need to update the `COPY` statements in the Dockerfile accordingly.


```
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
```

With the Dockerfile ready, run `docker build`. For example, since I have an account called "clayford" on Docker Hub, I would run:

```
docker build . -t clayford/research_project:v1
```

Once built, I can push to Docker Hub as follows:

```
docker login
docker push clayford/research_project:v1
```

Now anyone can download and run the same exact computational environment as me. For example, let's say someone has a folder called "replicate_cf" where they want to replicate my work. They might run the following.

```
docker run --rm -ti -v ~/replicate_cf:/home/rstudio/project -e PASSWORD=pwd -p 8787:8787 clayford/research_project:v1
```

This will open the same container I used to analyze the data. It will contain the code and data and the same versions of R packages I used, as well as the same version of R and the same operating system.

If someone wanted to build this image they would need the Dockerfile, the code and the data, and the renv.lock file. These files are available in this GitHub repo if you would like to try building the image. The renv.lock file is a json file that can be viewed in a text editor if you want to see what versions of R packages are used. 


## Resources

Sites I referenced in writing this up.

Docker for the UseR    
<https://github.com/noamross/nyhackr-docker-talk>

Enough Docker to be Dangerous    
<https://seankross.com/2017/09/17/Enough-Docker-to-be-Dangerous.html>

R Docker tutorial   
<https://jsta.github.io/r-docker-tutorial/>

Ten simple rules for writing Dockerfiles for reproducible data science    
<https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1008316#sec002>

Docker for reproducible research    
<https://benkeser.github.io/info550/lectures/11_docker/docker.html#1>

An R reproducibility toolkit for the practical researcher    
<https://reproducibility.rocks/materials/>

Setting up a transparent reproducible R environment with Docker + renv   
<https://eliocamp.github.io/codigo-r/en/2021/08/docker-renv/>

Using renv with Docker   
<https://rstudio.github.io/renv/articles/docker.html>

Automating Computational Reproducibility in R using renv, Docker, and GitHub Actions  
<https://haines-lab.com/post/2022-01-23-automating-computational-reproducibility-with-r-using-renv-docker-and-github-actions/>


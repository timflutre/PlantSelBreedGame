---
title: PlantBreedGame
---

<!-- pandoc README.md -t html -s -o README.html --toc -->

# Overview

`PlantBreedGame` is a software implementing a **serious game** to teach **selective breeding** via the example of a fictitious annual **plant species** to students at the master level.
It takes the form of a [Shiny](http://shiny.rstudio.com/) application, benefiting from the [R](https://www.r-project.org/) programming language and software environment for statistical computing.

This software is available under a **free software** license, the [GNU Affero General Public License](https://www.gnu.org/licenses/agpl.html) (version 3 and later); see the COPYING file.
The copyright is owned by the [Institut National de la Recherche Agronomique](http://www.inra.fr/) (INRA) and [Montpellier SupAgro](http://www.supagro.fr/).

It is versioned using the [git](http://www.git-scm.com/) software, the central repository being hosted [here](https://github.com/timflutre/PlantBreedGame) on GitHub, and the institutional repository being hosted [there](https://sourcesup.renater.fr/projects/plantbreedgame/) on SourceSup.
The `README` file is available at [https://sourcesup.renater.fr/plantbreedgame/](https://sourcesup.renater.fr/plantbreedgame/).

# Example

You can discover an example online [here](http://www.agap-sunshine.inra.fr/breeding-game/).
But if you want to install the game on your own computer or server, read on!

# Installation

## Dependencies

Before using this game, you need to install R as well as various packages, listed in the file [`src/dependencies.R`](https://github.com/timflutre/PlantBreedGame/blob/master/src/dependencies.R).
Then it should work on Unix-like operating systems (GNU/Linux, Mac OS) as well as on Microsoft Windows.

## Locally on your computer

1. Retrieve the Shiny application, by [downloading](https://github.com/timflutre/PlantBreedGame/archive/master.zip) it as a ZIP archive (then unzip it and rename the directory).

Here is how to do it in a terminal for Unix-like operating systems:

```
wget https://github.com/timflutre/PlantBreedGame/archive/master.zip
unzip master.zip
mv PlantBreedGame-master PlantBreedGame
```

The package can also be installed after cloning the git repository:

```
git clone git@github.com:timflutre/PlantBreedGame.git
```

2. Then, enter into the `PlantBreedGame` directory; inside, run the script `plantbreedgame_setup.Rmd` using [Rmarkdown](http://rmarkdown.rstudio.com/) to simulate the initial data set. It also creates all the necessary files and database for the game to function, and initiate the game with two players, "test" (no password) and "admin" (password `1234`).

3. Finally, open a R session, and execute the following commands:

```
library(shiny)
setwd("path/to/PlantBreedGame")
runApp()
```

A web page should automatically open in your default web browser, and you should be able to start playing.
See the explanations below in the section "Usage".

## To set up your own server

_It is highly recommended to start by installing the application on your computer (see the previous section)._

First, you need to have a [Shiny server](https://www.rstudio.com/products/shiny/shiny-server/) installed and running, say, in `/srv/shiny-server`.
We only tested with the open source version, but it should also work with the pro version.
For all this, have a look at the official [documentation](http://docs.rstudio.com/shiny-server/).

Second, you need to add an application to the server.
Start by downloading, for instance in your home, our Shiny application as a ZIP archive or clone the git repository (see explanations in the previous section):

```
cd ~
wget https://github.com/timflutre/PlantBreedGame/archive/master.zip
unzip master.zip
mv PlantBreedGame-master PlantBreedGame
```

Then, create a new directory for the application (let's call it `breeding-game` here):

```
mkdir /srv/shiny-server/breeding-game
```

and copy inside the content of our Shiny application you just downloaded:

```
cp -r ~/PlantBreedGame-master/* /srv/shiny-server/breeding-game
```

By default, the Shiny server runs as a unix user named `shiny`.
You hence need to create a unix group, named for instance `breeding`, to which the `shiny` user can be added (the Shiny server may need to be restarted for this to be taken into account).

Everything inside the `breeding-game` directory should be readable and writable for users who are part of the `breeding` group.
This is particularly the case for the data set (`data` directory, generated by running `plantbreedgame_setup.Rmd`, see the previous section).

```
chgrp -R breeding /srv/shiny-server/breeding-game
chmod -R ug+rw,o-rwx /srv/shiny-server/breeding-game
```

Now go to the URL of the `breeding-game` application made available by your Shiny server.
If you encounter an error, look at the log, for instance:

```
less /var/log/shiny-server/breeding-game-shiny-20180129-100752-39427.log
```

Errors may be due to missing packages, otherwise report an issue (see below).
Once all requested packages are installed, you should be able to start playing.
See the explanations below in the section "Usage".

## :whale2: Docker

Thank to docker, you can deploy this application without not installing anything more than docker on your server.

To install docker please refer here: [ubuntu](https://docs.docker.com/install/linux/docker-ce/ubuntu/), [debian](https://docs.docker.com/install/linux/docker-ce/debian/), [other](https://docs.docker.com/install/).

### Deployment

A docker image of this application is available on Docker Hub: [juliendiot/plantbreedgame](https://hub.docker.com/r/juliendiot/plantbreedgame).

#### 1st method

The simplest way to deploy the application on a server using docker is with this command:

```sh
docker run -d --rm --name plantbreedgame --user shiny -p 80:3838 juliendiot/plantbreedgame
```

The application is then accessible on the host machine on port `80` at the path `/PlantBreedGame`, for example: `localhost:80/PlantBreedGame` on your personal computer.

Be careful, stopping this container will erase all the progress of the players.

#### 2nd method

This method is for people who want persistant game progress, a manual access to the `data` folder of the game and an access to the application's logs.

In order to access to the `data` folder of the game, we must first extract this folder from the image:

```sh
docker run -d --rm --name plantbreedgame juliendiot/plantbreedgame
docker cp plantbreedgame:/srv/shiny-server/PlantBreedGame/data /host/path/to/appData
docker stop plantbreedgame
chgrp docker -R /host/path/to/appData
chmod 774 /host/path/to/appData
chmod 664 /host/path/to/appData/breeding-game.sqlite
```

Then we must create a folder for the logs:

```sh
mkdir /host/path/to/log
chgrp docker /host/path/to/log
```

We can now mount these folders on a new running the container :

```sh
docker run -d --rm --name plantbreedgame --user shiny -p 80:3838 \
    -v /host/path/to/appData:/srv/shiny-server/PlantBreedGame/data \
    -v /host/path/to/log:/var/log/shiny-server/ \
    juliendiot/plantbreedgame
```

Finally, we must give the same group id to the container's "shiny" group than the host's "docker" group:

```sh
docker exec -u 0 -it plantbreedgame groupmod -g $(cut -d: -f3 < <(getent group docker)) shiny
```

#### debug

To access to the a bash console from inside the container use:

```sh
docker exec -u 0 -it plantbreedgame bash
```

### customn build

If you want to use specific game parameters (define in the file `plantbreedgame_setup.Rmd`) you can build your own docker image:

1. get the application code:

```sh
wget https://github.com/timflutre/PlantBreedGame/archive/master.zip
unzip master.zip
mv PlantBreedGame-master PlantBreedGame
```

or

```sh
git clone --depth=1 https://github.com/timflutre/PlantBreedGame.git
```

2. modify the file `PlantBreedGame/plantbreedgame_setup.Rmd`
3. move in the app code folder and build a new image:

```sh
cd PlantBreedGame
docker build -t customplantbreedgame ./
```

You can then run this image by using the same commands as above replacing `juliendiot/plantbreedgame` by `customplantbreedgame`

# Usage

Once the application is installed and working, _please_ read the game rules (tab `How to play?`) and start by downloading the initial data set as well as example files showing how requests should be formatted (all files listed at the bottom of the tab `How to play?`).

Before making any request, such as phenotyping, you need to log in (tab `Identification`).
To get a sense of how the interface works, you can use the "test" breeder with the "tester" status which doesn't require any password and isn't subject to time restriction.

All your files, whether they are inputs for a request or outputs of a request, are available for download in the tab `Identification` (once logged in).
But remember that regular players (not testers nor the game master) have time restrictions.
This means that, even if a plant material request is successful, you will have to wait before using your new genotypes in other crosses or before requesting data on it.
Similarly, even if a phenotyping/genotyping request is successfull, you will have to wait before downloading the output file.

For your selection to work, you need to analyze the initial data carefully.
The `Theory` tab can be helpful.

The `Evaluation` tab can be used to compare new genotypes (from different players) with the initial lines.

If you want to organize a real playing session, you need to create as many breeders as there are players or player teams.
For this, you need to log in as the "admin" breeder with the "game-master" status.
Initially, its password is set to `1234`, but this can (and should!) be changed via the tab `Admin`.
This tab also allows a game master to create new breeders and sessions, among other things.

You can modify some key parameters of the game, e.g., effective population size, heritabilities, genetic correlation.
For this, you need to edit the setup file [`plantbreedgame_setup.Rmd`](https://github.com/timflutre/PlantBreedGame/blob/master/plantbreedgame_setup.Rmd), notably by changing the parameters' values in the sections `Simulate haplotypes and genotypes` and `Simulate phenotypes` (e.g., subsection `Simulation procedure for trait 1`).

# Citation

As the authors invested time and effort in creating this game, please cite the following [letter](https://dl.sciencesocieties.org/publications/cs/abstracts/0/0/cropsci2019.03.0183le) to the editor of Crop Science:

```
Flutre, T., Diot, J., and David, J. (2019). PlantBreedGame: A Serious Game that Puts Students in the Breeder’s Seat. Crop Science. DOI 10.2135/cropsci2019.03.0183le
```

# Acknowledgments

Thanks to Philippe Brabant (AgroParisTech) and Jean-Luc Jannink (Cornell) for their feedbacks.

# Issues

When encountering a problem with the package, you can report issues on GitHub directly ([here](https://github.com/timflutre/PlantBreedGame/issues)).

# Contributing

You can contribute in various ways:

- report an issue (online, see the above section);

- suggest improvements (in the same way as issues);

- propose a [pull request](https://help.github.com/articles/about-pull-requests/) (after creating a new branch).

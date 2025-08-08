FROM docker.io/library/ubuntu:noble

RUN apt-get -y update && apt-get -y install bash wget bzip2 restic

#Just basing on restic now
#RUN wget -qO - https://raw.githubusercontent.com/CupCakeArmy/autorestic/master/install.sh | bash

RUN apt-get clean && rm -rf /var/lib/apt/lists/*;

WORKDIR /

#No need for the text application now
#RUN apt-get -y update && apt-get -y install restic gettext-base

#Just basing on restic now
#COPY autorestic_preconfig.yml autorestic_preconfig.yml

#This is a symlink from ../../../../../../../@Commons/shell_scripts/restic/entrypoint.sh
COPY entrypoint.sh entrypoint.sh

ENTRYPOINT ["bash","entrypoint.sh"]

# docker build -t mgrast/jenkins-ssh-slave .

# this image give jenkins user sudo-right to execute docker 

FROM jenkins/ssh-slave:latest

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install sudo

RUN usermod -aG sudo jenkins

## allowing jenkins user to run sudo commands
RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
 ## avoid typing sudo in command line
RUN echo "alias docker='sudo docker '" >> /home/jenkins/.bashrc
RUN echo "alias docker='sudo docker-compose '" >> /home/jenkins/.bashrc

# create wrapper to avoid havin to use sudo
RUN /bin/echo -e '#!/bin/bash\nsudo -E /usr/bin/docker $@' > /usr/local/bin/docker
RUN chmod 775 /usr/local/bin/docker

RUN /bin/echo -e '#!/bin/bash\nsudo -E /usr/bin/docker-compose $@' > /usr/local/bin/docker-compose
RUN chmod 775 /usr/local/bin/docker-compose
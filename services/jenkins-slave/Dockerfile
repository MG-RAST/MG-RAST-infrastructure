
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


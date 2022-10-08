FROM ubuntu:rolling

# prereqs
# cpan: to wrangle perl (not needed but good to have)
# sudo: to wrangle conda's installation
# wget: to pull other stuff from GitHub
# vim:  everyone needs vim!
RUN apt-get update && apt-get install -y cpanminus && apt-get install -y sudo && apt-get install -y wget && apt-get install -y vim && apt-get clean

# install entrez direct
RUN sh -c "$(wget -q ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh -O -)"

# fix some perl stuff (might not be needed with conda but I'm taking no chances)
RUN mkdir perlstuff && cd perlstuff && cpan Time::HiRes && cpan File::Copy::Recursive && cd ..
ENV PERL5LIB=/perlstuff:/sra-tools-3.0.0/setup:/ncbi-vdb-3.0.0/setup

# installing the SRA toolkit the traditional way is a nightmare; we'll use conda instead
# we need to be specific about the label or else we'll get a version that throws SSL errors
RUN INSTALL_PATH=/root/miniconda3 && wget https://repo.anaconda.com/miniconda/Miniconda3-py37_4.12.0-Linux-x86_64.sh && sudo bash ./Miniconda3-py37_4.12.0-Linux-x86_64.sh -b -p $INSTALL_PATH && PATH=$INSTALL_PATH/bin:$PATH && conda init && conda install -c "bioconda/label/main" sra-tools

# set path variable (again)
ENV PATH=/root/miniconda3:/bin:/root/edirect/:/sra-tools-3.0.0:/ncbi-vdb-3.0.0/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
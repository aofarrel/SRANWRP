FROM ubuntu:jammy

# hard prereqs
# autoconf: install samtools/htslib/bcftools
# gcc: install samtools/htslib/bcftools
# lbzip2: install samtools/htslib/bcftools
# libbz2-dev: install samtools/htslib/bcftools
# make: install samtools/htslib/bcftools
# sudo: to wrangle conda's installation (might not be 100% necessary but may sidestep some issues)
# wget: to pull other stuff from GitHub
# zlib1g-dev: install samtools/htslib/bcftools
RUN apt-get update && apt-get install -y autoconf && apt-get install -y gcc && apt-get install -y lbzip2 && apt-get install -y libbz2-dev && apt-get install -y make && apt-get install -y sudo && apt-get install -y wget && apt-get install -y zlib1g-dev && apt-get clean

# soft prereqs: cpan, curl, pigz, tree, vim
RUN apt-get update && apt-get install -y cpanminus && apt-get install -y curl && apt-get install -y pigz && apt-get install -y tree && apt-get install -y vim && apt-get clean

# install entrez direct
RUN sh -c "$(wget -q ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh -O -)"

# install bedtools
RUN apt-get update && apt-get install -y bedtools && apt-get clean

# install the samtools trinity
RUN wget https://github.com/samtools/htslib/releases/download/1.16/htslib-1.16.tar.bz2 && tar -xf htslib-1.16.tar.bz2 && cd htslib-1.16 && ./configure
RUN wget https://github.com/samtools/samtools/releases/download/1.16.1/samtools-1.16.1.tar.bz2
RUN wget https://github.com/samtools/bcftools/releases/download/1.16/bcftools-1.16.tar.bz2

# fix some perl stuff (might not be needed with conda but I'm taking no chances)
RUN mkdir perlstuff && cd perlstuff && cpan Time::HiRes && cpan File::Copy::Recursive && cd ..
ENV PERL5LIB=/perlstuff:/sra-tools-3.0.0/setup:/ncbi-vdb-3.0.0/setup

# installing the SRA toolkit the traditional way is messy; we'll use conda instead
# we need to be specific about the label or else we'll get a version that throws SSL errors
RUN INSTALL_PATH=/root/miniconda3 && wget https://repo.anaconda.com/miniconda/Miniconda3-py37_4.12.0-Linux-x86_64.sh && sudo bash ./Miniconda3-py37_4.12.0-Linux-x86_64.sh -b -p $INSTALL_PATH && PATH=$INSTALL_PATH/bin:$PATH && conda init && conda install -c "bioconda/label/main" sra-tools

# set path variable (again)
ENV PATH=/root/miniconda3/bin:/bin:/root/edirect/:/sra-tools-3.0.0:/ncbi-vdb-3.0.0/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
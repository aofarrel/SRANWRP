########################## WARNING ##########################
# This code exits an interactive program improperly.
# It may cause your terminal to act in unexpected ways...
# The image itself is fine, but be cautious when building it!
#############################################################

FROM ubuntu:jammy

# hard prereqs
# autoconf:        install samtools/htslib/bcftools
# gcc:             install samtools/htslib/bcftools
# lbzip2:          install samtools/htslib/bcftools
# libbz2-dev:      install samtools/htslib/bcftools
# liblzma-dev:     use cram files
# libncurses5-dev: use samtools tview
# libssl-dev:      install python with pip
# make:            install samtools/htslib/bcftools
# sudo:            wrangle some installations (might not be 100% necessary)
# wget:            install most stuff
# zlib1g-dev:      install samtools/htslib/bcftools
RUN apt-get update && \
apt-get install -y autoconf && \
apt-get install -y gcc && \
apt-get install -y lbzip2 && \
apt-get install -y libbz2-dev && \
apt-get install -y liblzma-dev && \
apt-get install -y libncurses5-dev && \
apt-get install -y libssl-dev && \
apt-get install -y make && \
apt-get install -y sudo && \
apt-get install -y wget && \
apt-get install -y zlib1g-dev && \
apt-get clean

# soft prereqs: cpan, curl, fd-find, pigz, tree, vim
RUN apt-get update && \
apt-get install -y cpanminus && \
apt-get install -y curl && \
apt-get install -y fd-find && \
apt-get install -y pigz && \
apt-get install -y tree && \
apt-get install -y vim && \
apt-get clean

# python and friends
RUN wget https://www.python.org/ftp/python/3.11.1/Python-3.11.1.tgz && tar -xf Python-3.11.1.tgz && cd Python-3.11.1 && ./configure --disable-test-modules --enable-optimizations && make && sudo make install 
RUN pip3 install numpy
RUN pip3 install pandas
RUN pip3 install Matplotlib
RUN pip3 install firecloud

# install entrez direct
RUN sh -c "$(wget -q ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh -O -)"

# install bedtools
RUN apt-get update && apt-get install -y bedtools && apt-get clean

# install the samtools trinity (htslib will get installed with samtools)
RUN cd bin && wget https://github.com/samtools/samtools/releases/download/1.16.1/samtools-1.16.1.tar.bz2 && tar -xf samtools-1.16.1.tar.bz2 && cd samtools-1.16.1 && ./configure && make && make install
RUN cd bin && wget https://github.com/samtools/bcftools/releases/download/1.16/bcftools-1.16.tar.bz2 && tar -xf bcftools-1.16.tar.bz2 && cd bcftools-1.16 && ./configure && make && make install

# fix some perl stuff (might not be needed but I'm taking no chances)
RUN mkdir perlstuff && cd perlstuff && cpan Time::HiRes && cpan File::Copy::Recursive && cd ..
ENV PERL5LIB=/perlstuff:

# grab premade sra-tool binaries
RUN cd bin && wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/3.0.1/sratoolkit.3.0.1-ubuntu64.tar.gz && tar -xf sratoolkit.3.0.1-ubuntu64.tar.gz

# set path variable and some aliases
RUN echo 'alias python="python3"' >> ~/.bashrc
RUN echo 'alias pip="pip3"' >> ~/.bashrc
ENV PATH=/bin:/root/edirect/:/bin/sratoolkit.3.0.1-ubuntu64/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# attempt configure vdb
# !!this will cause a segfault!!
RUN x | vdb-config --interactive || :

# cleanup
RUN sudo rm /bin/bcftools-1.16.tar.bz2 && sudo rm /bin/samtools-1.16.1.tar.bz2 && sudo rm /bin/sratoolkit.3.0.1-ubuntu64.tar.gz && sudo rm Python-3.11.1.tgz && sudo rm -rf Python-3.11.1

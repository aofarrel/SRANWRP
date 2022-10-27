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
apt-get install -y make && \
apt-get install -y sudo && \
apt-get install -y wget && \
apt-get install -y zlib1g-dev && \
apt-get clean

# soft prereqs: cpan, curl, fd-find, pigz, python, tree, vim
RUN apt-get update && \
apt-get install -y cpanminus && \
apt-get install -y curl && \
apt-get install -y fd-find && \
apt-get install -y pigz && \
apt-get install -y python3.10 && \
apt-get install -y tree && \
apt-get install -y vim && \
apt-get clean

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
RUN cd bin && wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/3.0.0/sratoolkit.3.0.0-ubuntu64.tar.gz && tar -xf sratoolkit.3.0.0-ubuntu64.tar.gz

# set path variable and some aliases
RUN echo 'alias fdfind="fd"' >> ~/.bashrc
RUN echo 'alias python="python3.10"' >> ~/.bashrc
RUN echo 'alias python3="python3.10"' >> ~/.bashrc
RUN echo 'alias pydoc3="ydoc3.10"' >> ~/.bashrc
RUN echo 'alias pygettext3="pygettext3.10"' >> ~/.bashrc
ENV PATH=/bin:/root/edirect/:/bin/sratoolkit.3.0.0-ubuntu64/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# attempt configure vdb
# !!this will cause a segfault!!
RUN x | vdb-config --interactive || :

# cleanup
RUN sudo rm /bin/bcftools-1.16.tar.bz2 && sudo rm /bin/samtools-1.16.1.tar.bz2 && sudo rm /bin/sratoolkit.3.0.0-ubuntu64.tar.gz

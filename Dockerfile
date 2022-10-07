FROM ubuntu:rolling

# prereqs
# cmake: needed for ncbi-vdb
# cpan: to wrangle perl
# g++: needed for sra-tools
# wget: to pull other stuff from GitHub
# vim: everyone needs vim!
RUN apt-get update && apt-get install -y cmake && apt-get install -y cpanminus && apt-get install -y g++ && apt-get install -y wget && apt-get install -y vim && apt-get clean

# install entrez direct
RUN sh -c "$(wget -q ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh -O -)"

# fix some perl stuff
RUN mkdir perlstuff && cd perlstuff && cpan Time::HiRes && cpan File::Copy::Recursive && cd ..
ENV PERL5LIB=/perlstuff:/sra-tools-3.0.0/setup:/ncbi-vdb-3.0.0/setup

# set up NCBI VDB, needed for SRA toolkit
RUN wget https://github.com/ncbi/ncbi-vdb/archive/refs/tags/3.0.0.tar.gz && tar -xzf 3.0.0.tar.gz && rm -r 3.0.0.tar.gz
RUN cd ncbi-vdb-3.0.0 && ./configure && ./setup/install
ENV PATH=/root/edirect/:/ncbi-vdb-3.0.0:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# set up SRA toolkit
RUN wget https://github.com/ncbi/sra-tools/archive/refs/tags/3.0.0.tar.gz && tar -xzf 3.0.0.tar.gz && rm -r 3.0.0.tar.gz && mkdir /data
RUN ./sra-tools-3.0.0/configure

# set path variable (again)
ENV PATH=/root/edirect/:/sra-tools-3.0.0:/ncbi-vdb-3.0.0/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

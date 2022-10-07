FROM ubuntu:rolling
RUN apt-get update && apt-get install -y wget && apt-get install -y sudo && sudo apt-get install -y cpanminus && apt-get install -y vim && apt-get clean
RUN sh -c "$(wget -q ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh -O -)"
RUN wget https://github.com/ncbi/sra-tools/archive/refs/tags/3.0.0.tar.gz && tar -xzf 3.0.0.tar.gz && rm -r 3.0.0.tar.gz && mkdir /data
# fix some perl stuff
RUN mkdir perlstuff && cd perlstuff && sudo cpan > Time::HiRes && sudo cpan > File::Copy::Recursive
ENV PERL5LIB=/perlstuff
# set path variable
ENV PATH=/root/edirect/:/sra-tools-3.0.0:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

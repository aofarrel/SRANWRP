FROM ubuntu:jammy

# hard prereqs
# autoconf:        install samtools/htslib/bcftools
# gcc:             install samtools/htslib/bcftools
# git:             install seqtk
# lbzip2:          install samtools/htslib/bcftools
# libbz2-dev:      install samtools/htslib/bcftools
# libffi-dev:      fix some pip installs failing due to lack of '_ctypes' module
# liblzma-dev:     use cram files
# libncurses5-dev: use samtools tview
# libsqlite3-dev:  fix ete3 failing to import due to lack of '_seqlite3' module
# libssl-dev:      install python with pip
# make:            install samtools/htslib/bcftools
# sudo:            wrangle some installations (might not be 100% necessary)
# wget:            install most stuff
# zlib1g-dev:      install samtools/htslib/bcftools + seqtk

RUN apt-get update && \
apt-get install -y autoconf && \
apt-get install -y git && \
apt-get install -y gcc && \
apt-get install -y lbzip2 && \
apt-get install -y libbz2-dev && \
apt-get install -y libffi-dev && \
apt-get install -y liblzma-dev && \
apt-get install -y libncurses5-dev && \
apt-get install -y libsqlite3-dev && \
apt-get install -y libssl-dev && \
apt-get install -y make && \
apt-get install -y sudo && \
apt-get install -y wget && \
apt-get install -y zlib1g-dev && \
apt-get clean

# general utilities: bc, cpan, curl, fd-find, pigz, screen, tree, vim
# bc is used by parsevcf, but the others are just for good measure
RUN apt-get update && \
apt-get install -y bc && \
apt-get install -y cpanminus && \
apt-get install -y curl && \
apt-get install -y fd-find && \
apt-get install -y pigz && \
apt-get install -y screen && \
apt-get install -y tree && \
apt-get install -y vim && \
apt-get clean

# install python and friends (warning: this takes about 15 minutes)
RUN wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0rc3.tgz && tar -xf Python-3.12.0rc3.tgz && cd Python-3.12.0rc3 && ./configure --disable-test-modules --enable-optimizations && make && sudo make install 
RUN pip3 install ete3
RUN pip3 install tqdm
RUN pip3 install numpy
RUN pip3 install pandas
RUN pip3 install Matplotlib
RUN pip3 install firecloud
RUN pip3 install taxoniumtools

# install entrez direct
RUN sh -c "$(wget -q ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh -O -)"

# install bedtools
RUN apt-get update && apt-get install -y bedtools && apt-get clean

# install the samtools trinity (htslib will get installed with samtools)
RUN cd bin && wget https://github.com/samtools/samtools/releases/download/1.16.1/samtools-1.16.1.tar.bz2 && tar -xf samtools-1.16.1.tar.bz2 && cd samtools-1.16.1 && ./configure && make && make install
RUN cd bin && wget https://github.com/samtools/bcftools/releases/download/1.16/bcftools-1.16.tar.bz2 && tar -xf bcftools-1.16.tar.bz2 && cd bcftools-1.16 && ./configure && make && make install

# install seqtk
RUN git clone https://github.com/lh3/seqtk.git && cd seqtk && make && cd .. && mv seqtk bin/seqtk

# grab premade sra-tool binaries
## !! due to how SRANWRP works, we currently cannot update to 3.0.5 or higher !!
## 3.0.5 adds pacbio support to fasterq-dump, but sranwrp relies on that failure to avoid
## issues with clockwork, which only supports illumina data. 
RUN cd bin && wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/3.0.1/sratoolkit.3.0.1-ubuntu64.tar.gz && tar -xf sratoolkit.3.0.1-ubuntu64.tar.gz

# fix some perl stuff (might not be needed but I'm taking no chances)
RUN mkdir perlstuff && cd perlstuff && cpan Time::HiRes && cpan File::Copy::Recursive && cd ..
ENV PERL5LIB=/perlstuff:

# throw in the TB reference while we're at it (used by tree_nine, matches ref in clockwork-plus)
# see gs://topmed_workflow_testing/tb/ref/index_H37Rv_reference_output/Ref.H37Rv.tar
# md5sum should be fca996be5de559f5f9f789c715f1098b
RUN mkdir ref
COPY ./Ref.H37Rv.tar ./ref/
RUN cd ./ref/ && tar -xvf Ref.H37Rv.tar

# add typical TB masked sites (used by tree_nine)
RUN mkdir mask
RUN wget https://raw.githubusercontent.com/iqbal-lab-org/cryptic_tb_callable_mask/master/R00000039_repregions.bed && mv R00000039_repregions.bed ./mask/

# set path variable and some aliases
RUN echo 'alias python="python3"' >> ~/.bashrc
RUN echo 'alias pip="pip3"' >> ~/.bashrc
ENV PATH=/bin:/bin/seqtk:/root/edirect/:/bin/sratoolkit.3.0.1-ubuntu64/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# throw in some scripts
RUN mkdir scripts
RUN wget https://raw.githubusercontent.com/aofarrel/parsevcf/refs/tags/1.4.2/distancematrix_nwk.py && mv distancematrix_nwk.py ./scripts/
RUN wget https://gist.githubusercontent.com/aofarrel/a638f2ff05f579193632f7921832a957/raw/baa77b4f6afefd78ae8b6a833121a413bd359a5e/marcs_incredible_script && \
    mv marcs_incredible_script marcs_incredible_script.pl && mv marcs_incredible_script.pl ./scripts/

# cleanup
RUN sudo rm /bin/bcftools-1.16.tar.bz2 && sudo rm /bin/samtools-1.16.1.tar.bz2 && sudo rm /bin/sratoolkit.3.0.1-ubuntu64.tar.gz && sudo rm Python-3.12.0rc3.tgz && sudo rm -rf Python-3.12.0rc3

FROM arhodes77/rnaseq-trinty:dsl2
LABEL authors="Arhodes updates, Phil Ewels, Rickard Hammarén" \
      description="Docker image containing all software requirements for the nf-core/rnaseq pipeline plus trinity assembly"

# Install the conda environment
COPY environment.yml /
RUN conda env create --quiet -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/nf-core-rnaseq-1.4.3dev/bin:$PATH
# Dump the details of the installed packages to a file for posterity
RUN conda env export --name nf-core-rnaseq-1.4.3dev > nf-core-rnaseq-1.4.3dev.yml

# Instruct R processes to use these empty files instead of clashing with a local version
RUN touch .Rprofile
RUN touch .Renviron


#FROM trinityrnaseq/trinityrnaseq:2.8.4 

#ARG SKEWER_VERSION=0.2.2
#ARG TOOL_MULTIQC_VERSION=1.1
#ARG TRANS_DECODER_VERSION=5.5.0
#ARG HMMER_VERSION=3.2.1
#ARG DIAMOND_VERSION=0.9.24
#ARG SALMON_VERSION=0.13.1
#ARG STAR_VERSION=2.7.1a

# Installing salmon
#RUN bash -c 'curl -k -L https://github.com/COMBINE-lab/salmon/releases/download/v${SALMON_VERSION}/salmon-${SALMON_VERSION}_linux_x86_64.tar.gz > salmon.tar.gz'
#RUN tar -zvxf salmon.tar.gz
#RUN rm /usr/local/bin/salmon; ln -s $PWD/salmon-latest_linux_x86_64/bin/salmon /usr/local/bin/salmon

# Installing Diamond
#RUN bash -c 'curl -k -L https://github.com/bbuchfink/diamond/releases/download/v${DIAMOND_VERSION}/diamond-linux64.tar.gz > diamond-linux64.tar.gz'
#RUN tar -zvxf diamond-linux64.tar.gz; mv diamond /usr/local/bin/
#RUN chmod +x /usr/local/bin/diamond 

# Installing Skewer
#RUN bash -c 'curl -k -L https://downloads.sourceforge.net/project/skewer/Binaries/skewer-${SKEWER_VERSION}-linux-x86_64 > /usr/local/bin/skewer'
#RUN chmod +x /usr/local/bin/skewer

#Adding perl script for improving multiQC report
#RUN bash -c 'curl -k -L  https://github.com/CRG-CNAG/make_tool_desc_for_multiqc/archive/v${TOOL_MULTIQC_VERSION}.tar.gz > tool_ver.tar.gz'
#RUN tar -zvxf tool_ver.tar.gz
#RUN mv make_tool_desc_for_multiqc-${TOOL_MULTIQC_VERSION}/make_tool_desc_for_multiqc.pl /usr/local/bin/ 
#RUN chmod +x /usr/local/bin/make_tool_desc_for_multiqc.pl
#RUN rm -fr make_tool_desc_for_multiqc-* v${TOOL_MULTIQC_VERSION}.tar.gz 

# Installing TransDecoder and its dependencies
#RUN bash -c 'curl -k -L https://github.com/TransDecoder/TransDecoder/archive/TransDecoder-v${TRANS_DECODER_VERSION}.tar.gz > transdec.tar.gz'
#RUN tar -zvxf transdec.tar.gz; ln -s $PWD/TransDecoder-TransDecoder-v${TRANS_DECODER_VERSION}/TransDecoder.LongOrfs /usr/local/bin/; ln -s $PWD/TransDecoder-TransDecoder-v${TRANS_DECODER_VERSION}/TransDecoder.Predict /usr/local/bin/ 
#RUN Rscript -e 'source("http://bioconductor.org/biocLite.R");library(BiocInstaller); biocLite("seqLogo", dep = TRUE)'
#RUN R -e 'chooseCRANmirror(ind=52); install.packages(c("ggplot2"))'

# installing HMMER
#RUN bash -c 'curl -k -L http://eddylab.org/software/hmmer/hmmer-${HMMER_VERSION}.tar.gz > hmmer.tar.gz'
#RUN tar -zvxf hmmer.tar.gz; cd hmmer-${HMMER_VERSION}; ./configure; make; make install; cd easel; make install; cd ../../

# Installing STAR
#RUN bash -c 'curl -k -L https://github.com/alexdobin/STAR/archive/${STAR_VERSION}.tar.gz > STAR.tar.gz'
#RUN tar -zvxf STAR.tar.gz
#RUN cp STAR-${STAR_VERSION}/bin/Linux_x86_64/* /usr/local/bin/
#RUN rm STAR.tar.gz

#cleaning
#RUN rm -fr *.tar.gz* .tar.bz2

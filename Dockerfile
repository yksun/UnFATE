# start with miniconda3 as build environment
FROM continuumio/miniconda3 AS build

# Update, install mamba and conda-pack:
RUN conda update -n base -c defaults --yes conda && \
    conda install -c conda-forge -n base --yes mamba conda-pack

# Install unfate deps from bioconda
# here specifying specific versions to be able to set ENV below
RUN mamba create -c conda-forge -c bioconda -c defaults -c etetoolkit \
    -n unfate --yes "python=3.7" biopython==1.76 pandas seaborn click \
    blast spades exonerate hmmer trimal mafft \
    parallel \
    ete3 ete_toolchain ete3_external_apps \
    && conda clean -a -y

# Since we want the most recent, install from repo, remove snap as broken
SHELL ["conda", "run", "-n", "unfate", "/bin/bash", "-c"]
RUN git clone https://github.com/claudioametrano/UnFATE.git
RUN cd UnFATE
python3 main_wrap.py --first_use

# package with conda-pack
RUN conda-pack --ignore-missing-files -n unfate -o /tmp/env.tar && \
    mkdir /venv && cd /venv && tar xf /tmp/env.tar && \
    rm /tmp/env.tar

# We've put venv in same path it'll be in final image
RUN /venv/bin/conda-unpack

# Now build environment
FROM debian:buster AS runtime

# Copy /venv from the previous stage:
COPY --from=build /venv /venv

# Install debian snap via apt-get
RUN apt-get update && apt-get install -y default-jre && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/snap-hmm /usr/bin/snap && \
    rm "/venv/bin/fasta" && \
    ln -s "/venv/bin/fasta36" "/venv/bin/fasta"

# add it to the PATH and add env variables
ENV PATH="/venv/bin:$PATH" \
    Unfate="/venv/UnFATE" \
    USER="me"

# When image is run, run the code with the environment
SHELL ["/bin/bash", "-c"]
CMD main_wrap.py --help
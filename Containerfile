# Use a base image as the base
FROM ghcr.io/clamsproject/app-swt-detection:v7.4
ENV visaid_build_version=60cfadf67614251c215198a119a7dafc739a16de
# default subdirectory inside the zip file downloaded from github 
ENV visaid_dir=/visaid_builder-$visaid_build_version

WORKDIR /

RUN apt-get update && apt-get install -y \
    jq \
    wget \
    unzip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN wget -O visaid_builder.zip https://github.com/WGBH-MLA/visaid_builder/archive/$visaid_build_version.zip && \
    unzip visaid_builder.zip && \
    rm visaid_builder.zip

# Create a virtual environment
RUN python3 -m venv $visaid_dir/.venv
RUN $visaid_dir/.venv/bin/pip install -r $visaid_dir/requirements.txt

COPY . /

# Ensure the script has execution permissions
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]

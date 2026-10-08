# Use a base image as the base
FROM ghcr.io/clamsproject/app-swt-detection:v9.2
ENV visaid_build_version=251c2ee0b4158698d8917a2c539ad0602fb5ddbd
# source code of visaid_builder, with its own virtual environment inside, so that
# its dependencies do not interfere with the ones of the SWT app in the base image
ENV visaid_dir=/visaid_builder

WORKDIR /

RUN apt-get update && apt-get install -y \
    jq \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# the name of the top directory in the zip file follows the name of the github
# repository, hence unzip to a temporary location and move whatever is in there
RUN wget -O visaid_builder.zip https://github.com/WGBH-MLA/visaid-builder/archive/$visaid_build_version.zip && \
    unzip -q visaid_builder.zip -d /tmp/visaid_builder && \
    mv /tmp/visaid_builder/* $visaid_dir && \
    rm -r visaid_builder.zip /tmp/visaid_builder

# visaid_builder reads its HTML/CSS/JS templates from the source directory, and
# a regular (non-editable) install leaves them out
RUN python3 -m venv $visaid_dir/.venv && \
    $visaid_dir/.venv/bin/pip install --no-cache-dir -e $visaid_dir

COPY . /

# Ensure the script has execution permissions
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]


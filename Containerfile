# Use a base image as the base
FROM ghcr.io/clamsproject/app-swt-detection:v7.4

WORKDIR /

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade pip  

RUN wget -O visaid_builder.zip https://github.com/WGBH-MLA/visaid_builder/archive/refs/heads/main.zip && \
    unzip visaid_builder.zip && \
    rm visaid_builder.zip && \
    mv visaid_builder-main visaid_builder

# Create a virtual environment
RUN python3 -m venv /visaid_builder/.venv && \
    /visaid_builder/.venv/bin/pip install --upgrade pip && \
    /visaid_builder/.venv/bin/pip install pandas==2.0.3 && \ 
    /visaid_builder/.venv/bin/pip install -r /visaid_builder/requirements.txt

COPY . /

# Ensure the script has execution permissions
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]

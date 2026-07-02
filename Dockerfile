FROM rocker/shiny-verse:latest

# Install necessary system libraries
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Miniforge (comes with mamba)
RUN curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" && \
    sh Miniforge3-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniforge3-Linux-x86_64.sh

# Create the flopy_env environment using mamba
RUN /opt/conda/bin/mamba create -y -p /opt/flopy_env -c conda-forge \
    python=3.11 \
    flopy \
    pandas \
    numpy && \
    /opt/conda/bin/mamba clean -afy

# Install additional R packages required by the app
RUN install2.r -e \
    reticulate \
    plotly \
    DT \
    bslib \
    shinymanager \
    scrypt

# Copy the app files into the Shiny Server directory
COPY app.R /srv/shiny-server/
COPY scripts/ /srv/shiny-server/scripts/
# Bundled demo listing files (loaded instantly by the in-app demo selector).
COPY demo/ /srv/shiny-server/demo/

# Update the python path in app.R to point to the docker container's flopy_env
RUN sed -i 's|/home/pawel/miniforge3/envs/flopy_env/bin/python|/opt/flopy_env/bin/python|g' /srv/shiny-server/app.R

# Copy and set up the entrypoint script to pass environment variables
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Ensure correct permissions
RUN chown -R shiny:shiny /srv/shiny-server

# Expose port and run entrypoint
EXPOSE 3838
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

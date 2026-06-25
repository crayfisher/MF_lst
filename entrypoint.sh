#!/bin/bash

# If RGWCHART_PASSWORD is set, write it to /srv/shiny-server/.Renviron 
# so that the R session spawned by shiny-server can read it.
if [ -n "$RGWCHART_PASSWORD" ]; then
    echo "RGWCHART_PASSWORD=\"$RGWCHART_PASSWORD\"" > /srv/shiny-server/.Renviron
    chown shiny:shiny /srv/shiny-server/.Renviron
fi

# Execute the default shiny-server command
exec /usr/bin/shiny-server

FROM python:3.6-alpine
LABEL maintainer="David A."

ENV ODOO_URL = ""
ENV PGADMIN_URL = ""

WORKDIR /opt
RUN pip install Flask
COPY app-code/ .
COPY releases.txt icenvvars.sh /tmp/
RUN sh /tmp/icenvvars.sh

EXPOSE 8080

ENTRYPOINT [ "/media/icvars" ]

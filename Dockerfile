FROM python:3.6-alpine
LABEL maintainer="David A."



WORKDIR /opt
RUN pip install Flask
COPY app-code/ .
COPY releases.txt icenvvars.sh /tmp/
RUN sh /tmp/icenvvars.sh

EXPOSE 8080

#RUN sh /media/icvars
ENTRYPOINT [ "/media/icvars" ]
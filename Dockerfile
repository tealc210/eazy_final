FROM python:3.6-alpine
LABEL maintainer="David A."

ENV ODOO_URL=""
ENV PGADMIN_URL=""

WORKDIR /opt
RUN pip install Flask
COPY app-code/ .

EXPOSE 8080

ENTRYPOINT [ "python", "app.py" ]
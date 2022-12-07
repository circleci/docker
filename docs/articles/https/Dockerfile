FROM debian:11.5

RUN apt-get update && apt-get install -yq openssl

ADD make_certs.sh /


WORKDIR /data
VOLUME ["/data"]
CMD /make_certs.sh

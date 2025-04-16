FROM mongo:latest
ADD keyfile /data/keyfile
RUN chmod 400 /data/keyfile/key
RUN chown -R mongodb:mongodb /data/keyfile
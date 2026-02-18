FROM alpine:3.20

RUN apk add --no-cache \
    postgresql16-client \
    aws-cli \
    bash \
    tzdata

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

CMD ["backup.sh"]

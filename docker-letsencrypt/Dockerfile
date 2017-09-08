FROM alpine

# Credit: @frol for python3 - https://github.com/frol/docker-alpine-python3/blob/master/Dockerfile

# deps - python3 openssl curl sed grep mktemp
# boto3 - AWS SDK for python
RUN apk add --no-cache --virtual .build-deps git \
    && apk add --no-cache --virtual .dehydrated-rundeps python3 bash openssl curl jq gettext \
    && pip3 install --upgrade pip boto3 awscli \
    && rm -r /root/.cache \

    && cd /tmp \
    && git clone https://github.com/lukas2511/dehydrated.git --depth 1 \
    && chmod a+x dehydrated/dehydrated \
    && mv dehydrated/dehydrated /usr/bin/ \
    && rm -rf /tmp/* \

    && apk del .build-deps

COPY config /etc/dehydrated/

COPY route53-change-record-template.json /

COPY dehydrated-dns-custom /usr/bin/

COPY update-certificates /

COPY assume-role /

COPY docker-entrypoint /
ENTRYPOINT ["/docker-entrypoint"]

CMD ["/update-certificates"]

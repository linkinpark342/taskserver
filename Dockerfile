FROM alpine:3.7 AS builder

RUN apk add --no-cache cmake make g++ gnutls-dev util-linux-dev gnutls-utils

COPY cmake /usr/app/cmake
COPY demo /usr/app/demo
COPY doc /usr/app/doc
COPY mon /usr/app/mon
COPY pki /usr/app/pki
COPY scripts /usr/app/scripts
COPY src /usr/app/src
COPY test /usr/app/test
COPY *.h *.h.in AUTHORS ChangeLog cmake* CMakeLists.txt COPYING INSTALL NEWS /usr/app/

RUN mkdir -p /usr/app/build \
    && cd /usr/app/build \
    && cmake -DCMAKE_BUILD_TYPE=release .. \
    && make \
    && make DESTDIR=/app/ install

RUN cd /usr/app/pki \
    && ./generate

FROM alpine:3.7

RUN apk add --no-cache gnutls gnutls-c++ libuuid gnutls-utils

COPY --from=builder /app/ /

RUN addgroup -S taskd && adduser -S -h /var/lib/taskd -D -G taskd taskd
ENV TASKDDATA=/var/lib/taskd
USER taskd

RUN taskd init
COPY --from=builder --chown=taskd:taskd /usr/app/pki/ ${TASKDDATA}/pki/
RUN for i in api.cert api.key ca.cert ca.key server.cert server.crl server.key; do \
        taskd config --force $i ${TASKDDATA}/pki/$i.pem; \
    done \
    && taskd config --force log /dev/stdout \
    && taskd config --force server "0.0.0.0:53589"

WORKDIR /var/lib/taskd
VOLUME [ "/var/lib/taskd" ]

CMD taskd server --data "${TASKDDATA}"

EXPOSE 53589

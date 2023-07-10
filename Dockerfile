
FROM alpine:3.18 as builder
RUN apk update &&\
    # Required by dnsmasq
    apk add alpine-sdk linux-headers git &&\
    git clone git://thekelleys.org.uk/dnsmasq.git &&\
    # Required by sniproxy
    apk add autoconf automake gettext gettext-dev libtool libev libev-dev pcre pcre-dev udns udns-dev bsd-compat-headers &&\
    git clone https://github.com/dlundquist/sniproxy.git

# Building dnsmasq
WORKDIR /dnsmasq
# disable FTP, DHCP in dnsmasq
RUN sed -i "0a\#define NO_TFTP"  src/config.h &&\
    sed -i "0a\#define NO_DHCP"  src/config.h &&\
    sed -i "0a\#define NO_DHCP6" src/config.h &&\
    sed -i "0a\#define NO_IPSET" src/config.h &&\
    sed -i "0a\#define NO_AUTH" src/config.h &&\
    make all

# Building sniproxy
WORKDIR /sniproxy
RUN ./autogen.sh &&\
    ./configure &&\
    make


FROM alpine:3.18
# Copy dnsmasq from builder
COPY --from=builder /dnsmasq/src/dnsmasq /usr/local/bin/dnsmasq
RUN chmod 755 /usr/local/bin/dnsmasq

# Copy custom resolv file
COPY src/resolv.dnsmasq.conf /etc/resolv.dnsmasq.conf

# Copy dnsmasq config file
COPY src/dnsmasq.conf /etc/dnsmasq.conf
RUN mkdir -p /etc/dnsmasq.d/

# Copy sniproxy from builder
COPY --from=builder /sniproxy/src/sniproxy /usr/local/bin/sniproxy
RUN chmod 755 /usr/local/bin/dnsmasq

# Copy sniproxy config file
COPY src/sniproxy.conf /etc/sniproxy.conf

# Update & install wireguard
RUN apk update &&\
    apk add --no-cache tini wireguard-tools libev pcre udns

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
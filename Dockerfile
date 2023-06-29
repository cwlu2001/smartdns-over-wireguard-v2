
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

# Using custom upstream dns server
RUN touch /etc/resolv.dnsmasq.conf &&\
    echo "nameserver 1.1.1.1" >> /etc/resolv.dnsmasq.conf &&\
    echo "nameserver 8.8.8.8" >> /etc/resolv.dnsmasq.conf

# Generate dnsmasq config file
RUN touch /etc/dnsmasq.conf &&\
    echo "port=53"                                    >> /etc/dnsmasq.conf &&\
    echo "resolv-file=/etc/resolv.dnsmasq.conf"       >> /etc/dnsmasq.conf &&\
    echo "no-hosts"                                   >> /etc/dnsmasq.conf &&\
    echo "conf-file=/etc/dnsmasq.d/spoofed.list.conf" >> /etc/dnsmasq.conf
RUN mkdir -p /etc/dnsmasq.d/

# Copy sniproxy from builder
COPY --from=builder /sniproxy/src/sniproxy /usr/local/bin/sniproxy
RUN chmod 755 /usr/local/bin/dnsmasq

# Generate sniproxy config file
RUN touch /etc/sniproxy.conf &&\
    echo "listen 0.0.0.0:443 {"     >> /etc/sniproxy.conf && \
    echo "    proto tls"            >> /etc/sniproxy.conf && \
    echo "    table default"        >> /etc/sniproxy.conf && \
    echo "    fallback 0.0.0.0:443" >> /etc/sniproxy.conf && \
    echo "}"                        >> /etc/sniproxy.conf && \
    echo "table default {"          >> /etc/sniproxy.conf && \
    echo "    .* *:443"             >> /etc/sniproxy.conf && \
    echo "}"                        >> /etc/sniproxy.conf

# Update & install wireguard
RUN apk update &&\
    apk add --no-cache tini wireguard-tools libev pcre udns

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
FROM alpine:3.23

ARG YAZI_VERSION=v26.1.22
ARG TARGETARCH

ENV YAZI_CONFIG_HOME=/root/.config/yazi
ENV YAZI_PLUGINS_DIR=/root/.config/yazi/plugins
ENV WORKSPACE_DIR=/workspace/mux.yazi

RUN apk add --no-cache \
  bash \
  ca-certificates \
  curl \
  file \
  git \
  libstdc++ \
  unzip

RUN case "${TARGETARCH:-amd64}" in \
    amd64) YAZI_ARCH='x86_64-unknown-linux-musl' ;; \
    arm64) YAZI_ARCH='aarch64-unknown-linux-musl' ;; \
    *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
  esac \
  && echo "Installing Yazi ${YAZI_VERSION} for ${YAZI_ARCH}" \
  && curl -fsSL "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${YAZI_ARCH}.zip" -o /tmp/yazi.zip \
  && unzip /tmp/yazi.zip -d /tmp \
  && install -m 0755 /tmp/yazi-${YAZI_ARCH}/yazi /usr/local/bin/yazi \
  && install -m 0755 /tmp/yazi-${YAZI_ARCH}/ya /usr/local/bin/ya \
  && rm -rf /tmp/yazi.zip /tmp/yazi-${YAZI_ARCH}

RUN mkdir -p "${YAZI_PLUGINS_DIR}" "${WORKSPACE_DIR}" "${YAZI_CONFIG_HOME}"

RUN mkdir -p /opt/mux-dev

COPY docker/entrypoint.sh /usr/local/bin/mux-dev-entrypoint

RUN chmod +x /usr/local/bin/mux-dev-entrypoint

WORKDIR /workspace/mux.yazi
ENTRYPOINT ["/usr/local/bin/mux-dev-entrypoint"]
CMD ["bash"]

# setup aws-auth and kubectl
FROM docker.io/bitnami/minideb:bookworm AS aws_setup
USER root
RUN apt-get update && apt-get install -y curl
# install gettext for envsubst to replace environment var placeholders in kubernetes manifests
RUN apt-get install -y gettext-base
RUN curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.6.27/aws-iam-authenticator_0.6.27_linux_amd64 && chmod +x ./aws-iam-authenticator
RUN mv ./aws-iam-authenticator /usr/local/bin
RUN curl -LO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# add binaries to image running as 1001 user
FROM docker.io/bitnami/minideb:bookworm
COPY --from=aws_setup /usr/local/bin/kubectl /usr/local/bin/
COPY --from=aws_setup /usr/local/bin/aws-iam-authenticator /usr/local/bin/
COPY --from=aws_setup /usr/bin/envsubst /usr/local/bin/
USER root
RUN useradd -u 1001 -m cli_user
RUN groupadd -g 997 docker || true
RUN usermod -aG docker cli_user
USER 1001
WORKDIR /home/cli_user/
ENTRYPOINT [ "/bin/bash", "-c" ]
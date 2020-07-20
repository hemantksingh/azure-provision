FROM microsoft/azure-cli

RUN apk update
RUN apk add ansible terraform jq
# RUN curl https://releases.hashicorp.com/terraform/0.12.6/terraform_0.12.6_linux_amd64.zip --out terraform.zip && \
# unzip terraform.zip && \
# rm -f terraform.zip && \
# mv terraform /usr/local/bin/ && \
# mkdir /terraform && \
# apk update && \
# apk add jq && \
# rm -rf /var/cache/apk/* && \
# mkdir /terraform/modules

# Install kubernetes cli
RUN az aks install-cli
RUN terraform --version
RUN ansible --version

WORKDIR /app
COPY src .
COPY aks.tf .

RUN chmod +x *.sh

ENTRYPOINT ["terraform"]
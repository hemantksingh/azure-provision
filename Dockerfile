FROM microsoft/azure-cli

RUN curl https://releases.hashicorp.com/terraform/0.12.6/terraform_0.12.6_linux_amd64.zip --out terraform.zip && \
unzip terraform.zip && \
rm -f terraform.zip && \
mv terraform /usr/local/bin/ && \
mkdir /terraform && \
apk update && \
apk add jq && \
rm -rf /var/cache/apk/* && \
mkdir /terraform/modules

WORKDIR /terraform
COPY src .
RUN terraform init
# COPY run-uat.sh /terraform/run.sh
# COPY modules /terraform/modules
# RUN chmod +x /terraform/run.sh
# ENTRYPOINT ["/terraform/run.sh"]
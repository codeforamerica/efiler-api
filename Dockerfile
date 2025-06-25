# This Dockerfile is designed for production, not development. If you want to run it in development you can do the following:
# docker build -t efiler-api --platform linux/amd64 .
# docker run -p 4567:4567 efiler-api

FROM ruby:3.4.4

COPY . .

# JDK installation instructions from https://adoptium.net/installation/linux/
RUN wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null \
  && echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list \
  && apt-get update && apt install -y temurin-21-jdk
ENV VITA_MIN_JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64

RUN bundle install

# Tell Docker to listen on port 4567.
EXPOSE 4567

# Tell Docker that when we run "docker run", we want it to
# run the following command:
# $ bundle exec rackup --host 0.0.0.0 -p 4567.
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]
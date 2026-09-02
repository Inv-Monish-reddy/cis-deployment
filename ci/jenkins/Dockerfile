FROM jenkins/jenkins:lts-jdk21

USER root

# Static Docker CLI (uses host daemon via /var/run/docker.sock)
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.3.1.tgz \
    | tar xz -C /usr/local/bin --strip-components=1 docker/docker \
    && chmod +x /usr/local/bin/docker

# SonarQube Scanner - use Jenkins JDK 21 instead of bundled Java 17
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip git \
    && curl -fsSL https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip -o /tmp/sonar.zip \
    && unzip -q /tmp/sonar.zip -d /opt \
    && rm -rf /opt/sonar-scanner-5.0.1.3006-linux/jre \
    && echo "sonar.scanner.javaExePath=/opt/java/openjdk/bin/java" >> /opt/sonar-scanner-5.0.1.3006-linux/conf/sonar-scanner.properties \
    && ln -sf /opt/sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner \
    && rm /tmp/sonar.zip \
    && rm -rf /var/lib/apt/lists/*

USER jenkins

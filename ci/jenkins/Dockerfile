FROM jenkins/jenkins:lts-jdk21

USER root

# Docker CLI - uses host Docker daemon via mounted /var/run/docker.sock
RUN apt-get update \
    && apt-get install -y --no-install-recommends docker.io curl unzip git \
    && rm -rf /var/lib/apt/lists/*

# SonarQube Scanner
RUN curl -fsSL https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip -o /tmp/sonar.zip \
    && unzip -q /tmp/sonar.zip -d /opt \
    && ln -sf /opt/sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner \
    && rm /tmp/sonar.zip

USER jenkins

# Dockerfile
FROM eclipse-temurin:21-jre-alpine

RUN apk update
#RUN apk add eclipse-temurin:21-jre-alpine

# Install tzdata package
RUN apk add --no-cache tzdata

# Set timezone to Asia/Kolkata (India)
ENV TZ=Asia/Kolkata
RUN cp /usr/share/zoneinfo/Asia/Kolkata /etc/localtime \
    && echo "Asia/Kolkata" > /etc/timezone

VOLUME /tmp
# Create directories
RUN mkdir -p /cisBackend
RUN mkdir -p /cisBackend/logs
RUN mkdir -p /cisBackend/config

# Copy jar file
COPY DragerCISBackend-0.0.1-SNAPSHOT.jar /cisBackend/DragerCISBackend-0.0.1-SNAPSHOT.jar
COPY ./config/application.properties /cisBackend/config
# Note: springboot config file path is given in SPRING_CONFIG_ADDITIONAL_LOCATION of docker-compose.yml
ENTRYPOINT ["java","-jar","/cisBackend/DragerCISBackend-0.0.1-SNAPSHOT.jar", "--spring.config.location=/cisBackend/config/application.properties"]
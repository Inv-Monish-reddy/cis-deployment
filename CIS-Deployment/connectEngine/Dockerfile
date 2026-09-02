# Dockerfile
FROM eclipse-temurin:21-jdk

# Install tzdata
RUN apt-get update && apt-get install -y tzdata && rm -rf /var/lib/apt/lists/*

# Set timezone
ENV TZ=Asia/Kolkata


VOLUME /tmp
# Create a directory called /app/logs
RUN mkdir -p /connectEngine
RUN mkdir -p /connectEngine/logs
RUN mkdir -p /connectEngine/config
RUN mkdir -p /connectEngine/driverJarsDump
# Copy connect engine jar
COPY device-connect-engine-0.0.1-SNAPSHOT.jar /connectEngine/device-connect-engine-0.0.1-SNAPSHOT.jar
# Copy drivers.xml and driver jar files
COPY ./driverJarsDump/drivers.xml /connectEngine/driverJarsDump/drivers.xml
COPY ./driverJarsDump/*.jar /connectEngine/driverJarsDump/
COPY ./config/application.properties /connectEngine/config
# Note: springboot config file path is given in SPRING_CONFIG_ADDITIONAL_LOCATION of docker-compose.yml
ENTRYPOINT ["java","-jar","/connectEngine/device-connect-engine-0.0.1-SNAPSHOT.jar", "--spring.config.location=/connectEngine/config/application.properties"]
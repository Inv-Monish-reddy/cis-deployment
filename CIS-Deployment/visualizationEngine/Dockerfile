FROM eclipse-temurin:21-jdk

# Install tzdata package
# Install tzdata
RUN apt-get update && apt-get install -y tzdata && rm -rf /var/lib/apt/lists/*

# Set timezone
ENV TZ=Asia/Kolkata


VOLUME /tmp
# Create directories
RUN mkdir -p /visualizationEngine
RUN mkdir -p /visualizationEngine/logs
RUN mkdir -p /visualizationEngine/config
# Copy jar file
COPY device-visualization-engine-0.0.1-SNAPSHOT.jar /visualizationEngine/device-visualization-engine-0.0.1-SNAPSHOT.jar
COPY ./config/application.properties /visualizationEngine/config
# Note: springboot config file path is given in SPRING_CONFIG_ADDITIONAL_LOCATION of docker-compose.yml
ENTRYPOINT ["java","-jar","/visualizationEngine/device-visualization-engine-0.0.1-SNAPSHOT.jar", "--spring.config.location=/visualizationEngine/config/application.properties"]
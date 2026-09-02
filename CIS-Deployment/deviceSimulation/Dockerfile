# Dockerfile
FROM eclipse-temurin:8-jdk-alpine


RUN apk update
RUN apk add --no-cache tzdata



# Set timezone
ENV TZ=Asia/Kolkata


VOLUME /tmp

RUN mkdir -p /deviceSimulation/deviceData /deviceSimulation/script

COPY device-simulation-0.0.1-SNAPSHOT.jar /deviceSimulation/device-simulation-0.0.1-SNAPSHOT.jar
COPY ./deviceData/*.data /deviceSimulation/deviceData/
COPY ./script/startSimulation.sh /deviceSimulation/script/

RUN chmod +x /deviceSimulation/script/startSimulation.sh

ENTRYPOINT ["sh", "/deviceSimulation/script/startSimulation.sh"]
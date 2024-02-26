FROM maven:3-eclipse-temurin-17 AS build

WORKDIR /app
COPY . ./
RUN mvn clean install -U

FROM eclipse-temurin:17-jre-alpine
RUN apk upgrade
#RUN	apt-get update && apt-get install -y curl iputils-ping wget
COPY --from=build /app/target/obds2fhir*with-dependencies.jar /obds2fhir/obds2fhir.jar
ADD src/docker/start.sh                         /obds2fhir/
RUN chmod +x                                    /obds2fhir/start.sh
ENTRYPOINT ["obds2fhir/start.sh"]


ENV FILE_PATH "/obds2fhir/clinical_data"
ENV STORE_PATH "http://blaze:8090/fhir"
ENV STORE_AUTH ""
ENV IDENTIFIER_SYSTEM "http://dktk.dkfz.de/fhir/onco/core/CodeSystem/PseudonymArtCS"
ENV MAINZELLISTE_URL "http://host.docker.internal:8080"
ENV MAINZELLISTE_APIKEY ""
ENV IDTYPE ""
ENV SALT "createLocalCustomSalt"
ENV SSL_CERTIFICATE_VALIDATION "true"
ENV ADD_DEPARTMENTS "false"
ENV WAIT_FOR_CONNECTION="false"
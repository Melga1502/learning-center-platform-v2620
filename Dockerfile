# Build stage: Maven + Temurin 26 JDK
# Etapa 1: aquí se COMPILA. Esta imagen trae Maven y el JDK, pero no viaja a la imagen final.
FROM maven:3.9-eclipse-temurin-26-noble AS build
WORKDIR /workspace

# Primero solo el pom.xml: así Docker guarda en caché las dependencias descargadas
# y no las vuelve a bajar si solo cambió el código.
COPY pom.xml .
RUN mvn -B -DskipTests dependency:go-offline

# Ahora sí el código fuente, y se empaqueta el .jar (sin ejecutar las pruebas: ya las corre Jenkins)
COPY src ./src
RUN mvn -B -DskipTests package

# Runtime stage: Temurin 26 JRE
# Etapa 2: aquí se EJECUTA. Solo el JRE (sin Maven ni el código), por eso la imagen final es pequeña.
FROM eclipse-temurin:26-jre-noble
WORKDIR /app

# Se copia únicamente el .jar generado en la etapa anterior
COPY --from=build /workspace/target/*.jar app.jar

# La aplicación escucha en el 8096 (server.port=${PORT:8096})
EXPOSE 8096

# Los datos de la base (DB_HOST, DB_PASSWORD...) se pasan al ejecutar con -e, no se guardan aquí
ENTRYPOINT ["java", "-jar", "app.jar"]

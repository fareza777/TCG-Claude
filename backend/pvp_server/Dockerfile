FROM dart:stable AS build

WORKDIR /src
COPY packages/shardfall_engine /src/packages/shardfall_engine
COPY backend/pvp_server /src/backend/pvp_server
COPY app/assets/data/set01.json /src/app/assets/data/set01.json

WORKDIR /src/backend/pvp_server
RUN dart pub get
RUN mkdir -p /out
RUN dart compile exe bin/server.dart -o /out/shardfall_pvp_server

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install --no-install-recommends --yes ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/shardfall_pvp_server /usr/local/bin/shardfall_pvp_server
COPY --from=build /src/app/assets/data/set01.json /opt/shardfall/app/assets/data/set01.json

ENV SHARDFALL_CARD_DATA=/opt/shardfall/app/assets/data/set01.json
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/shardfall_pvp_server"]

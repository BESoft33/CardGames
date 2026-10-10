# The game server as a container (docs/backend-setup.md). Build from the
# repository root, because the server shares packages with the app:
#   docker build -f server/Dockerfile -t cardgames-server .
# Its settings come from the environment at run time (see bin/server.dart);
# no secret is baked into the image.
FROM dart:3.13.5 AS build
WORKDIR /src
# The pub workspace includes the Flutter app, which this image cannot
# resolve; the server is built as a standalone package instead.
COPY packages/game_core packages/game_core
COPY packages/game_twentynine packages/game_twentynine
COPY packages/sync_protocol packages/sync_protocol
COPY server server
RUN for dir in packages/game_core packages/game_twentynine packages/sync_protocol server; do \
      sed -i '/^resolution: workspace$/d' "$dir/pubspec.yaml"; \
    done && \
    printf 'dependency_overrides:\n  game_core:\n    path: ../packages/game_core\n  game_twentynine:\n    path: ../packages/game_twentynine\n  sync_protocol:\n    path: ../packages/sync_protocol\n' > server/pubspec_overrides.yaml && \
    for dir in packages/game_twentynine packages/sync_protocol; do \
      printf 'dependency_overrides:\n  game_core:\n    path: ../game_core\n' > "$dir/pubspec_overrides.yaml"; \
    done
WORKDIR /src/server
RUN dart pub get && dart compile exe bin/server.dart -o /server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /server /server
EXPOSE 8080
ENTRYPOINT ["/server"]

FROM djs55/ocaml AS build

MAINTAINER David Scott <dave@recoil.org>

COPY . /src
RUN opam pin add -y inotify-event /src

FROM scratch
COPY --from=build /home/opam/.opam/default/bin/inotify-events /inotify-events
ENTRYPOINT [ "/inotify-events" ]

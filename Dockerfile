FROM djs55/ocaml AS build

MAINTAINER David Scott <dave@recoil.org>

COPY . /src
RUN opam pin add -y inotify-event /src

#FROM scratch
#COPY --from=build /src

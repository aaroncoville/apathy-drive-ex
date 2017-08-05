FROM trenpixster/elixir:1.3.4

ENV REFRESHED_AT 2016-06-23

ADD . /usr/src/app
WORKDIR /usr/src/app

ARG MIX_ENV
ENV MIX_ENV ${MIX_ENV}

RUN mix deps.get

RUN mix compile && mix phoenix.digest && mix release.clean && mix release --verbose --env=${MIX_ENV}

FROM elixir:1.17.3

RUN apt-get update && apt-get install postgresql-client -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./ /rujira-api

WORKDIR /rujira-api

ENV MIX_ENV=prod

RUN mix deps.get
RUN mix deps.compile 2>/dev/null

CMD [ "./scripts/entrypoint.sh" ]
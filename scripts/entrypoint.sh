#!/bin/bash

if [ -z "${DATABASE_URL}" ]; then
	echo DATABASE_URL not provided
	exit 1
fi

export DB="$(sed 's/^ecto/postgres/' <<< ${DATABASE_URL})"

# check if db already created
if [ ! $(psql $DB -l > /dev/null) ]; then
	echo "run initial setup..."
	mix ecto.setup --force
fi

# start server
mix phx.server

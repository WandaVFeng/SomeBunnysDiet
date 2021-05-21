## SomeBunnysDiet

### flyway
We migrated the PostgreSQL version of the common data model to [flyway](https://flywaydb.org/).  This structure make it simple to create databases reliably from source control.  We chose to represent each table as a [versioned migration](https://flywaydb.org/documentation/concepts/migrations#versioned-migrations) with a four digit numeric sequence.  This means that each script will run once upon initialization (__docker-compose up__) If you were to run the migrate command manually, it will skip the code that it has already run.

### persistent data
_/volumes/data_ will hold the data for your PostgreSQL database.  It is persisted here so you do not lose your work when you shut down the container.

### database
You will have a local PostgreSQL running inside a container.  The database is called 'postgres' and the username / password for your local instance is just 'admin'.

### usage

Initialize

```
docker-compose up
```

Drop into database container's shell.
```
docker-compose run postgres bash
```

From the database container's shell, interact with the database with the psql client.
```
psql --host=postgres --username=admin --dbname=postgres
```

Run all flyway migrations in your database
```
docker-compose run flyway migrate -configFiles=/flyway/conf/flyway.conf -locations=filesystem:/flyway/sql/public -schemas=public
```

Drop all objects in your database
```
docker-compose run flyway clean -configFiles=/flyway/conf/flyway.conf -locations=filesystem:/flyway/sql/public -schemas=public
```

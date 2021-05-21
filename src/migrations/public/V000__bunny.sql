--HINT DISTRIBUTE ON RANDOM
CREATE TABLE bunny
(
  bunny_id INTEGER,
  bunny_name VARCHAR(10)
)
;

COPY bunny FROM '/opt/bunny.csv' WITH CSV HEADER;

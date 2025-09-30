sysbench --db-driver=pgsql \
  --threads=1 \
  --pgsql-host=localhost \
  --pgsql-port=5432 \
  --pgsql-db=test1 \
  --pgsql-user=postgres \
  --pgsql-password=qwe123 \
  test.lua prepare --execute-queries='SET AUTOCOMMIT = 1;'

sysbench --db-driver=pgsql \
  --threads=1 \
  --pgsql-host=localhost \
  --pgsql-port=5433 \
  --pgsql-db=test1 \
  --pgsql-user=postgres \
  --pgsql-password=qwe123 \
  test.lua cleanup --execute-queries='SET AUTOCOMMIT = 1;'

sysbench --db-driver=pgsql \
  --threads=50 \
  --time=10 \
  --events=0 \
  --report-interval=1 \
  --pgsql-host=localhost \
  --pgsql-port=5432 \
  --pgsql-db=test1 \
  --pgsql-user=postgres \
  --pgsql-password=qwe123 \
  test.lua run --execute-queries='SET AUTOCOMMIT = 1;'

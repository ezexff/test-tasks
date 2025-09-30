function prepare()
    db_query("create table test (a int)")
    db_query("insert into test values (1)")
end

function event()
    db_query("update test set a = a + " .. sb_rand(1, 1000))
end

function cleanup()
    db_query("DROP TABLE test")
end
module SQLTestHelpers
  def assert_sql(expected, actual, msg = nil)
    expected = strip_sql(expected)
    actual = strip_sql(actual)
    assert_equal expected, actual, msg
  end
  def strip_sql(sql)
    sql.squish.gsub(/\s+/, " ").gsub(" ( ", " (").gsub(" ) ", ") ")
  end
end

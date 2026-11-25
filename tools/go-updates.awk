function satisfies(actual, minimum,   a,b,i,version) {
  if (actual == minimum) return 1
  if (actual !~ /^v[0-9]+\.[0-9]+\.[0-9]+([-+].*)?$/) return 0
  version = actual
  sub(/^v/, "", actual)
  sub(/^v/, "", minimum)
  split(actual, a, ".")
  split(minimum, b, ".")
  for (i = 1; i <= 3; i++) {
    if (a[i]+0 != b[i]+0) return a[i]+0 > b[i]+0
  }
  return version !~ /-/
}
NR == FNR {
  if (NF >= 3 && $1 !~ /^#/) {
    module[++n] = $1
    minimum[n] = $2
    target[n] = $3
    series[n] = $4
  }
  next
}
$1 == "dep" { dep = $2; actual[dep] = $3; next }
$1 == "=>" && dep != "" { replacement[dep] = $2 "@" $3 }
{ dep = "" }
END {
  for (i = 1; i <= n; i++) {
    m = module[i]
    if (!(m in actual)) continue
    if (minimum[i] == "replace") {
      if (replacement[m] != target[i]) print "replace", m "=" target[i]
    } else if (series[i] == "" || index(actual[m], series[i]) == 1) {
      if (m in replacement) {
        print "Unreviewed replacement for " m ": " replacement[m] > "/dev/stderr"
        exit 1
      }
      if (!satisfies(actual[m], minimum[i])) print "require", m "@" target[i]
    }
  }
}

#!/usr/bin/env -S jumpscript Roc
app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.23.0/GNN5tt2gKdX4dhawg4915C4YB193woHFdcCkz31fhGxv.tar.zst" }

import pf.OsStr
import pf.Stdout

main! : List(OsStr) => Try({}, _)
main! = |args| {
	Stdout.line!("Roc hello ${U64.to_str(List.len(args))}")?
	Ok({})
}

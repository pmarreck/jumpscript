#!/usr/bin/env -S jumpscript Roc
main! = |args| {
    echo!("Roc hello ${U64.to_str(List.len(args))}")
    Ok({})
}

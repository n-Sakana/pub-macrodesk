# VBA lexer fixtures

`test-large-modules.json` contains the exact UTF-8 bytes returned by
`MacroStudio.BookIO.ReadProject` for every visible-code module in
`testdata/test_large.xlsm`. Each entry records its SHA-256 digest so the
PowerShell extraction path and the Node lexer path can verify the same text.

`synthetic-edge-cases.bas` covers syntax that the small real workbook does
not contain. The Node test also constructs CRLF, LF, no-final-newline,
Japanese, and surrogate-pair variants explicitly.

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

Write-Host '[1/3] Bundling JS (esbuild)...'
npx --yes esbuild "$root\src\main.js" --bundle --minify --legal-comments=none --target=es2019 --outfile="$root\vendor\bundle.js"
if ($LASTEXITCODE -ne 0) { throw 'esbuild failed' }

Write-Host '[2/3] Obfuscating app bundle...'
npx --yes javascript-obfuscator "$root\vendor\bundle.js" --output "$root\vendor\obf" `
  --compact true `
  --control-flow-flattening true --control-flow-flattening-threshold 0.25 `
  --string-array true --string-array-encoding rc4 --string-array-threshold 1 `
  --string-array-rotate true --string-array-shuffle true `
  --split-strings true --split-strings-chunk-length 16 `
  --transform-object-keys true `
  --identifier-names-generator hexadecimal `
  --unicode-escape-sequence false `
  --rename-globals false
if ($LASTEXITCODE -ne 0) { throw 'obfuscation failed' }

$bundle = Get-Content "$root\vendor\obf\bundle.js" -Raw -Encoding UTF8
$three  = Get-Content "$root\node_modules\three\build\three.min.js" -Raw -Encoding UTF8
$orbit  = Get-Content "$root\node_modules\three\examples\js\controls\OrbitControls.js" -Raw -Encoding UTF8
foreach ($js in @($bundle, $three, $orbit)) {
  if ($js -match '</script' -or $js -match '<!--') { throw 'inline JS contains script-breaking sequences' }
}

Write-Host '[3/3] Assembling index.html...'
$head = Get-Content "$root\src\head.html" -Raw -Encoding UTF8
$css  = Get-Content "$root\vendor\ol.css" -Raw -Encoding UTF8
$html = $head.Replace('{{OL_CSS}}', $css)
$html = $html + "`n<script>`n" + $three + "`n</script>`n<script>`n" + $orbit + "`n</script>`n<script>`n" + $bundle + "`n</script>`n</body>`n</html>`n"
[IO.File]::WriteAllText("$root\index.html", $html, (New-Object System.Text.UTF8Encoding($false)))

"Done. index.html size: $([math]::Round((Get-Item "$root\index.html").Length / 1KB)) KB"

# Local mini-server for the radar site (loopback only).
param([switch]$NoOpen)
$ErrorActionPreference = 'Stop'
# Приватные адреса источников хранятся в base64 и собираются при запуске.
$SrcHost = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aHR0cHM6Ly93d3cubm93Y2FzdC5ydQ=='))
$GifHost1 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('bWV0ZW9yYWQucnU='))
$GifHost2 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('d3d3Lm1ldGVvaW5mby5ydQ=='))
$RefBase = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aHR0cHM6Ly93d3cubm93Y2FzdC5ydS8='))
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$port = 8471
$listener = $null
while ($port -lt 8490) {
  $listener = [System.Net.HttpListener]::new()
  try {
    $listener.Prefixes.Add("http://127.0.0.1:$port/")
    $listener.Start()
    break
  } catch {
    $listener.Close()
    $port++
  }
}
if (-not $listener.IsListening) { throw 'Could not bind a port in 8471..8489' }

$url = "http://127.0.0.1:$port/index.html"
if (-not $NoOpen) { Start-Process $url }
Write-Host "Radar site is running: $url"
Write-Host 'Close this window (or press Ctrl+C) to stop the server.'

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'text/javascript; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.png'  = 'image/png'
  '.svg'  = 'image/svg+xml'
  '.ico'  = 'image/x-icon'
  '.json' = 'application/json'
  '.map'  = 'application/json'
}

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $path = $ctx.Request.Url.AbsolutePath
  if ($path.StartsWith('/nc/')) {
    # Прозрачная пересылка к публичному API источника (токен выдаётся любому посетителю).
    # Разрешённые префиксы: /get_token, /baltrad_wsgi, /xsection/, /demo/viz/tiles.json
    $sub = $path.Substring(3)
    $allowed = $sub -eq '/get_token' -or $sub -eq '/demo/viz/tiles.json' -or $sub.StartsWith('/baltrad_wsgi') -or $sub.StartsWith('/xsection/')
    if ($allowed) {
      $done = $false
      for ($attempt = 0; $attempt -lt 3 -and -not $done; $attempt++) {
        try {
          $req = [System.Net.HttpWebRequest]::Create(($SrcHost + $sub + $ctx.Request.Url.Query))
          $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36'
          $req.Referer = $RefBase
          $req.Timeout = 120000
          $req.ReadWriteTimeout = 120000
          $req.KeepAlive = $false
          $resp = $req.GetResponse()
          $ms = New-Object System.IO.MemoryStream
          $resp.GetResponseStream().CopyTo($ms)
          $bytes = $ms.ToArray()
          $resp.Close()
          $ctx.Response.ContentType = $resp.ContentType
          $ctx.Response.Headers['Cache-Control'] = 'no-cache'
          $ctx.Response.ContentLength64 = $bytes.Length
          $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
          $done = $true
        } catch {
          $code = 502
          if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $code = [int]$_.Exception.Response.StatusCode }
          if ($code -eq 404) {
            try { $ctx.Response.StatusCode = 404 } catch {}
            $done = $true
            break
          }
          Start-Sleep -Milliseconds 900
        }
      }
      if (-not $done) { try { $ctx.Response.StatusCode = 502 } catch {} }
      try { $ctx.Response.OutputStream.Close() } catch {}
    } else {
      $ctx.Response.StatusCode = 403
      try { $ctx.Response.OutputStream.Close() } catch {}
    }
    continue
  }
  if ($path -eq '/proxy') {
    # Отдача кадров радара с того же origin (нужно данным клетки, срезу и 3D).
    # Белый список: только статичные PNG-кадры источника.
    $u = $ctx.Request.QueryString['url']
    $ok = ($u -match ('^' + [Regex]::Escape($SrcHost) + '/demo/viz/mytiles/[A-Za-z0-9_]+\.png$')) -or
      ($u -match ('^https://' + [Regex]::Escape($GifHost1) + '/static/phenomena24\.gif$')) -or
      ($u -match ('^https://' + [Regex]::Escape($GifHost2) + '/hmc-output/rmap/phenomena\.gif$')) -or
      ($u -match ('^https://' + [Regex]::Escape($GifHost2) + '/res/nowcast/[0-9]+/[A-Za-z0-9_/]+\.php\?')) -or
      ($u -match ('^https://' + [Regex]::Escape($GifHost2) + '/hmc-output/nowcast3/nowcast\.php$'))
    if ($ok) {
      try {
        $req = [System.Net.HttpWebRequest]::Create($u)
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36'
        $req.Timeout = 30000
        $req.ReadWriteTimeout = 30000
        $resp = $req.GetResponse()
        $ms = New-Object System.IO.MemoryStream
        $resp.GetResponseStream().CopyTo($ms)
        $bytes = $ms.ToArray()
        $ctx.Response.ContentType = $resp.ContentType
        $ctx.Response.Headers['Cache-Control'] = 'max-age=600'
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $resp.Close()
      } catch {
        $code = 502
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $code = [int]$_.Exception.Response.StatusCode }
        try { $ctx.Response.StatusCode = if ($code -eq 404) { 404 } else { 502 } } catch {}
      } finally {
        try { $ctx.Response.OutputStream.Close() } catch {}
      }
    } else {
      $ctx.Response.StatusCode = 403
      try { $ctx.Response.OutputStream.Close() } catch {}
    }
    continue
  }
  try {
    $path = $ctx.Request.Url.AbsolutePath
    if ($path -eq '/') { $path = '/index.html' }
    $rel = $path.TrimStart('/').Replace('/', '\')
    if ($rel -like '*..*') {
      $ctx.Response.StatusCode = 403
    } else {
      $file = Join-Path $root $rel
      if (Test-Path $file -PathType Leaf) {
        $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
        $bytes = [IO.File]::ReadAllBytes($file)
        $ctx.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        if ($ext -eq '.html') { $ctx.Response.Headers['Cache-Control'] = 'no-cache' }
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      } else {
        $ctx.Response.StatusCode = 404
      }
    }
  } catch {
    try { $ctx.Response.StatusCode = 500 } catch {}
  } finally {
    try { $ctx.Response.OutputStream.Close() } catch {}
  }
}

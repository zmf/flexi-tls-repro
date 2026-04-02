# Fastly TLS Flexi Repro (Standalone)

This folder is a fully isolated repro app for Fastly support.

It creates dynamic backends with different TLS options and performs a single upstream fetch per case.

## Cases

- `strict-valid-google`
  - `useSSL: true`
  - `sniHostname: "www.google.com"`
  - `certificateHostname: "www.google.com"`
  - target: `www.google.com:443`
- `flexi-valid-google`
  - `useSSL: true`
  - `sniHostname: undefined`
  - `certificateHostname: undefined`
  - target: `www.google.com:443`
- `strict-expired-badssl`
  - `useSSL: true`
  - `sniHostname: "expired.badssl.com"`
  - `certificateHostname: "expired.badssl.com"`
  - target: `expired.badssl.com:443`
- `flexi-expired-badssl`
  - `useSSL: true`
  - `sniHostname: undefined`
  - `certificateHostname: undefined`
  - target: `expired.badssl.com:443`

## Run with Docker

```bash
docker build -t fastly-tls-flexi-repro .
docker run --rm fastly-tls-flexi-repro
```

The container uses pinned tooling from `package.json`:

- `@fastly/js-compute` `3.40.1`
- `@fastly/cli` `14.2.0`
- `webpack` `5.99.9`
- `webpack-cli` `5.1.4`

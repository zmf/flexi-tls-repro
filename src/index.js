/// <reference types="@fastly/js-compute" />

import { Backend } from "fastly:backend";

const CASES = {
  "strict-valid-google": {
    host: "www.google.com",
    path: "/robots.txt",
    useSSL: true,
    sniHostname: "www.google.com",
    certificateHostname: "www.google.com",
  },
  "flexi-valid-google": {
    host: "www.google.com",
    path: "/robots.txt",
    useSSL: true,
  },
  "strict-expired-badssl": {
    host: "expired.badssl.com",
    path: "/",
    useSSL: true,
    sniHostname: "expired.badssl.com",
    certificateHostname: "expired.badssl.com",
  },
  "flexi-expired-badssl": {
    host: "expired.badssl.com",
    path: "/",
    useSSL: true,
    sniHostname: undefined,
    certificateHostname: undefined,
  },
};

function errorWithCauses(error) {
  const parts = [];
  const seen = new Set();
  let current = error;
  let depth = 0;
  while (current && depth < 6 && !seen.has(current)) {
    seen.add(current);
    const label = depth === 0 ? "error" : `cause_${depth}`;
    const name = current?.name ?? "Error";
    const msg =
      typeof current?.message === "string"
        ? current.message
        : typeof current === "string"
          ? current
          : JSON.stringify(current);
    parts.push(`${label}: ${name}: ${msg}`);
    current = current?.cause;
    depth += 1;
  }
  return parts.join(" | ");
}

function errorDiagnostics(error) {
  if (!error || (typeof error !== "object" && typeof error !== "function")) {
    return { kind: typeof error, value: String(error) };
  }

  const names = Object.getOwnPropertyNames(error);
  const diag = {};
  for (const key of names) {
    try {
      const value = error[key];
      diag[key] =
        typeof value === "string" || typeof value === "number" || typeof value === "boolean" || value === null
          ? value
          : Object.prototype.toString.call(value);
    } catch {
      diag[key] = "<unreadable>";
    }
  }
  return diag;
}

function json(status, bodyObj) {
  return new Response(JSON.stringify(bodyObj, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
    },
  });
}

async function runCase(caseName) {
  const cfg = CASES[caseName];
  if (!cfg) {
    return json(404, {
      error: "unknown_case",
      available_cases: Object.keys(CASES),
    });
  }

  const backend = new Backend({
    name: `repro-${caseName}`,
    target: `${cfg.host}:443`,
    useSSL: cfg.useSSL,
    connectTimeout: 10000,
    firstByteTimeout: 30000,
    betweenBytesTimeout: 30000,
    tlsMinVersion: 1,
    tlsMaxVersion: 1.3,
  });

  const info = {
    case: caseName,
    target: `${cfg.host}:443`,
    requestPath: cfg.path,
    backendOptions: {
      useSSL: cfg.useSSL,
      sniHostname: cfg.sniHostname ?? null,
      certificateHostname: cfg.certificateHostname ?? null,
    },
  };

  try {
    console.log(`[repro] Running case ${caseName}: ${JSON.stringify(info.backendOptions)}`);
    const upstream = await fetch(`https://${cfg.host}${cfg.path}`, {
      method: "GET",
      backend,
      headers: {
        host: cfg.host,
      },
    });
    const body = await upstream.text();
    return json(200, {
      ok: true,
      ...info,
      upstreamStatus: upstream.status,
      bodySnippet: body.slice(0, 220),
    });
  } catch (error) {
    const details = errorWithCauses(error);
    const diagnostics = errorDiagnostics(error);
    console.error(`[repro] Case ${caseName} failed: ${details}`);
    return json(500, {
      ok: false,
      ...info,
      errorDetails: details,
      errorDiagnostics: diagnostics,
    });
  }
}

addEventListener("fetch", (event) => {
  event.respondWith(
    (async () => {
      const url = new URL(event.request.url);
      if (url.pathname === "/") {
        return json(200, {
          service: "fastly-tls-flexi-repro",
          usage: "/case/<case-name>",
          cases: Object.keys(CASES),
        });
      }

      if (!url.pathname.startsWith("/case/")) {
        return json(404, {
          error: "not_found",
          usage: "/case/<case-name>",
          cases: Object.keys(CASES),
        });
      }

      const caseName = url.pathname.replace("/case/", "");
      return runCase(caseName);
    })()
  );
});

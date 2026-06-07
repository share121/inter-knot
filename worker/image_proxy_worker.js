export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (request.method !== 'GET') {
      return new Response('Method Not Allowed', { status: 405, headers: corsHeaders() });
    }
    const target = url.searchParams.get('url');
    if (!target) {
      return new Response('Missing url', { status: 400, headers: corsHeaders() });
    }
    let targetUrl;
    try {
      targetUrl = new URL(target);
    } catch {
      return new Response('Invalid url', { status: 400, headers: corsHeaders() });
    }
    if (!['https:', 'http:'].includes(targetUrl.protocol)) {
      return new Response('Invalid protocol', { status: 400, headers: corsHeaders() });
    }
    const upstream = await fetch(targetUrl.toString(), {
      headers: { 'User-Agent': 'inter-knot-image-proxy' },
    });
    const headers = new Headers(upstream.headers);
    headers.set('Access-Control-Allow-Origin', '*');
    headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    headers.set('Access-Control-Allow-Headers', 'Content-Type');
    headers.set('Cache-Control', 'public, max-age=3600');
    return new Response(upstream.body, { status: upstream.status, headers });
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Cache-Control': 'public, max-age=3600',
  };
}

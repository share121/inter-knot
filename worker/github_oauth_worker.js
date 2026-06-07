export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const allowedOrigin = getAllowedOrigin(origin, env);
    if (!allowedOrigin) {
      return new Response('Origin not allowed', { status: 403 });
    }

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(allowedOrigin),
      });
    }

    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return new Response('Invalid JSON', { status: 400 });
    }

    const { code, redirect_uri, code_verifier } = payload;
    if (!code || !redirect_uri || !code_verifier) {
      return new Response('Missing fields', { status: 400 });
    }

    const tokenRes = await fetch('https://github.com/login/oauth/access_token', {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        client_id: env.GITHUB_CLIENT_ID,
        client_secret: env.GITHUB_CLIENT_SECRET,
        code,
        redirect_uri,
        code_verifier,
      }),
    });
    let data;
    try {
      data = await tokenRes.json();
    } catch (err) {
      const text = await tokenRes.text();
      data = {
        error: 'invalid_response',
        error_description: 'GitHub token exchange returned non-JSON response.',
        status: tokenRes.status,
        body: text,
      };
    }

    if (!tokenRes.ok) {
      data = {
        error: 'github_error',
        error_description: 'GitHub token exchange failed.',
        status: tokenRes.status,
        body: data,
      };
    }

    return new Response(JSON.stringify(data), {
      status: tokenRes.status,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders(allowedOrigin),
      },
    });
  }
};

function getAllowedOrigin(origin, env) {
  const raw = (env.ALLOWED_ORIGIN || '').split(',').map((v) => v.trim());
  const allowList = raw.filter(Boolean);
  if (allowList.length === 0 || allowList.includes('*')) {
    return origin || '*';
  }
  return allowList.includes(origin) ? origin : '';
}

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Vary': 'Origin',
  };
}

import 'package:inter_knot/helpers/web_url_stub.dart'
    if (dart.library.html) 'package:inter_knot/helpers/web_url_web.dart'
    as impl;

void replaceUrl(String url) => impl.replaceUrl(url);

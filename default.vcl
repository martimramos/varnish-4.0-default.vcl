vcl 4.0;
# Default backend definition. Set this to point to your content server.
import std;
import directors;
#  ___               _                     _      
# | _ )  __ _   __  | |__  ___   _ _    __| |  ___
# | _ \ / _` | / _| | / / / -_) | ' \  / _` | (_-<
# |___/ \__,_| \__| |_\_\ \___| |_||_| \__,_| /__/
backend lgi_pub_priv_vip {
    .host = "HA_PROXY_IP";
    .port = "80";
    .max_connections = 500;
    .probe = {
        .url = "/haproxycheck";
        .expected_response = 200;
        .timeout = 1s;
        .interval = 5s;
        .window = 5;
        .threshold = 3;
        .initial = 2;
  }
    .first_byte_timeout = 300s;
    .connect_timeout = 5s;
    .between_bytes_timeout = 3s;
}
#
#     /_\    / __| | |      | _ )  ___   __ _  (_)  _ _    ___
#    / _ \  | (__  | |__    | _ \ / -_) / _` | | | | ' \  (_-<
#   /_/ \_\  \___| |____|   |___/ \___| \__, | |_| |_||_| /__/
# 
acl lgi_pub_priv_network {
    
    "IP_1";
    "IP_2";
    "IP_3";
    "IP_4";
}
acl purge {          # Who is allowed to purge?
    "localhost";
    "127.0.0.1";
    "172.0.0.0"/24; # can purge
    "10.0.0.0"/16; # can purge
}
# __   __   ___   _      _      
# \ \ / /  / __| | |    ( )  ___
#  \ V /  | (__  | |__  |/  (_-<
#   \_/    \___| |____|     /__/



sub vcl_recv {

    if (req.url == "/varnishcheck") {
        return(synth(751,"health check OK!"));
    }

    if (client.ip ~ lgi_pub_priv_network) {
        set req.backend_hint = lgi_pub_priv_vip;
    }
    if (req.method == "PURGE") {
            if (!client.ip ~ purge) {
                    return(synth(405,"Not allowed."));
            }
            return (purge);
    }
    if (req.method == "BAN") {
            if (!client.ip ~ purge) {
                    return(synth(403, "Not allowed."));
            }
            ban("req.url ~ "+req.url);
            return(synth(200, "Ban added"));
    }

    if (
        (! ( req.url ~ "/.+-theme/(css/|images/|js/)" || req.url ~ "/documents/" ))
       ) {
          return(pass);
         }


}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    # 
    # You can do accounting or modifying the final object here.
  # Called before a cached object is delivered to the client.
  if (obj.hits > 0) { # Add debug header to see if it's a HIT/MISS and the number of hits, disable when not needed
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }

  set resp.http.X-Cache-Hits = obj.hits;
  unset resp.http.X-Varnish;
  return (deliver);
}
sub vcl_backend_response {

    if (beresp.ttl < 120s) {
       set beresp.ttl = 120s;
        unset beresp.http.Cache-Control;
    }   
    if (bereq.url ~ "/documents/") {
        set beresp.ttl = 3m;
        unset beresp.http.Cache-Control;
        unset beresp.http.cookie;
        unset beresp.http.Set-Cookie;
    }
    if (bereq.url ~ "/.+-theme/(css/|images/|js/)") {
        set beresp.ttl = 8h;
        unset beresp.http.Cache-Control;
        unset beresp.http.cookie;
        unset beresp.http.Set-Cookie;
    }

}

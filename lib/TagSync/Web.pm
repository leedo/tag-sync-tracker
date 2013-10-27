package TagSync::Web;

use JSON ();

sub import {
  my ($package) = caller;

  no strict 'refs';

  my $routes = [];

  foreach my $meth (qw{get put post}) {
    *{"$package\::$meth"} = sub {
      req($routes, uc $meth, @_);
    };
  }

  *{"$package\::del"} = sub {
    req($routes, "DELETE", @_);
  };

  *{"$package\::call"} = sub {
    call($routes, @_);
  };

  *{"$package\::not_found"}       = \&not_found;
  *{"$package\::api_response"}    = \&api_response;
  *{"$package\::api_response_ok"} = \&api_response_ok;
  *{"$package\::api_error"}       = \&api_error;
}

sub req {
  my ($routes, $method, $path, $handler) = @_;
  my $fixed;
  if (ref $path eq "Regexp") {
    $fixed = qr{^$path/?$};
  }
  else {
    $fixed = substr($path, -1, 1) eq "/" ?
      qr{^\Q$path\E$} : qr{^\Q$path\E/?$};
  }
  push @$routes, [$method, $fixed, $handler];
}

sub call {
  my ($routes, $self, $env) = @_;
  local $@;

  my $res = eval {
    my $req = $self->prepare_req($env);
    my $method = $req->parameters->{_method} || $req->method;
    my $path = $req->path;
    foreach (@$routes) {
      if ($method eq $_->[0]) {
        if ($path =~ $_->[1]) {
          my @captures = $path =~ $_->[1];
          return $_->[2]->($self, $req, @captures);
        }
      }
    }

    return not_found();
  };

  if ($@) {
    my ($error) = $@ =~ /(.*) at .+\.pm line \d+/;
    return api_error($error);
  }

  return $res;
}

sub not_found {
  return [
    404,
    ['Content-Type', 'text/plain'],
    ['not found']
  ];
}

sub api_response {
  return [
    200,
    ['Content-Type', 'text/javascript'],
    [JSON::encode_json($_[0] || [])]
  ];
}

sub api_response_ok {
  api_response { success => "ok" };
}

sub api_error {
  return [
    200,
    ['Content-Type', 'text/javascript'],
    [JSON::encode_json {error => $_[0] || "unknown error"}]
  ];
}

1;

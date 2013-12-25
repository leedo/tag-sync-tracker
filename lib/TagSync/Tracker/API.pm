package TagSync::Tracker::API;

use parent "Plack::Component";

use Plack::Util::Accessor qw{db auth};
use TagSync::Web;
use Encode;
use TagSync::Tracker::Request;
use Digest::SHA1 qw{sha1_hex};
use Digest::HMAC_SHA1 qw{hmac_sha1_hex};
use MIME::Base64;
use URI::Escape;
use JSON;

sub error {
  my ($self, $error) = @_;
  api_error($error);
}

sub prepare_req {
  my ($self, $env) = @_;
  my $req = TagSync::Tracker::Request::factory($env);

  if ($req->type eq "server") {
    my $sth = $self->db->run(sub {
      my $sth = $_->prepare(q{SELECT id FROM server WHERE token = ?});
      $sth->execute($req->token);
      $sth;
    });
    $req->set_id($sth->fetchrow_array);
  }
  else {
    my $user_id = $self->auth->auth_request($req);
    $req->set_id($user_id);

    # user request on behalf of server they admin
    if (my $server_id = $req->parameters->{server_request}) {
      my $sth = $self->db->run(sub {
        my $sth = $_->prepare(q{
          SELECT token,id FROM server WHERE id = ? AND user_id = ?
        });
        $sth->execute($server_id, $req->id);
        $sth;
      });
      
      if (my $row = $sth->fetchrow_hashref) {
        $req = TagSync::Tracker::Request::Server->new($env, $row->{token});
        $req->set_id($row->{id});
      }
    }
  }

  die "unable to authorize request" unless defined $req->id;

  $req;
}

sub limit {
  my ($req) = @_;
  my $page = $req->parameters->{page} || 1;
  ($page - 1) * 50, 50;
}

post qr{/upload/(\d+)/tags} => sub {
  my ($self, $req, $upload_id) = @_;
  my $tag = $req->parameters->{tag};

  return api_error "missing required tag"
    unless defined $tag;

  $self->db->txn(sub {
    $_->do(q{
      INSERT OR IGNORE INTO tag (slug) VALUES (?)
    }, undef, $tag);

    $_->do(q{
      INSERT OR IGNORE INTO upload_tag (upload_id, tag_id, user_id)
        SELECT ?,id,?
        FROM tag
        WHERE slug = ?
    }, undef, $upload_id, $req->id, $tag);
  });

  api_response_ok;
};

del qr{/upload/(\d+)/tag/([^/]+)} => sub {
  my ($self, $req, $upload_id, $tag_slug) = @_;

  $self->db->run(sub {
    my ($tag_id) = $_->selectrow_array(q{
      SELECT id FROM tag WHERE slug = ?
    }, undef, $tag_slug);

    die "invalid tag" unless defined $tag_id;

    $_->do(q{
      DELETE FROM upload_tag
      WHERE upload_id = ?
        AND tag_id = ?
        AND user_id = ?
    }, undef, $upload_id, $tag_id, $req->id);
  });

  api_response_ok;
};

post '/upload' => sub {
  my ($self, $req) = @_;

  die unless $req->type eq "user";
  my $p = $req->parameters;
  my $upload_id;

  for (qw{hash sig tags title artist size quality info filename streaming}) {
    die "$_ is required" unless defined $p->{$_} and $p->{$_} ne "";
  }

  for (qw{artist info filename title}) {
    $p->{$_} = decode "utf8", $p->{$_};
  }

  $self->db->txn(sub {
    my ($token) = $_->selectrow_array(q{
      SELECT token FROM server WHERE id = ?
    }, undef, $p->{server});

    die "invalid server" unless defined $token;
    die "invalid server sig" unless
      sha1_hex(join "", $token, @{$p}{qw{size hash}}) eq $p->{sig};

    my $sth = $_->prepare(q{
      INSERT INTO upload (user_id, artist, title, size, hash, info, quality, server, filename, image_url, streaming, upload_date)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    });

    $sth->execute($req->id, @{$p}{qw{artist title size hash info quality server filename image_url streaming}}, time);
    $upload_id = $_->last_insert_id("", "", "", "");

    die "failed to generate upload id" unless defined $upload_id;

    for my $slug (split ",", $p->{tags}) {
      $slug =~ s/^\s+//;
      $slug =~ s/\s+$//;
      $_->do(q{
        INSERT OR IGNORE INTO tag (slug) VALUES (?)
      }, undef, $slug);

      $_->do(q{
        INSERT OR IGNORE INTO upload_tag (upload_id, tag_id, user_id) 
          SELECT ?,tag.id,?
          FROM tag
          WHERE tag.slug = ?
      }, undef, $upload_id, $req->id, $slug); 
    }
  });

  api_response {upload => $upload_id};
};

get qr{/upload/([^/]+)/servers} => sub {
  my ($self, $req, $upload_id) = @_;
  my @servers;

  $self->db->run(sub {
    my $upload = $_->selectrow_hashref(q{
      SELECT * FROM upload WHERE id = ?
    }, undef, $upload_id);

    my $all = $_->prepare(q{
      SELECT * FROM server WHERE everything = 1
    });
    my $tags = $_->prepare(q{
      SELECT s.*
      FROM server AS s
      INNER JOIN tag_subscription AS ts
        ON ts.subscriber_id = s.id
      WHERE
        ts.type = "server"
        AND ts.tag_id IN (
          SELECT ut.tag_id
          FROM upload_tag AS ut
          WHERE ut.upload_id = ?
        )
    });

    my $users = $_->prepare(q{
      SELECT s.*
      FROM server AS s
      INNER JOIN user_subscription AS us
        ON us.subscriber_id = s.id
      WHERE us.type = "server"
        AND us.user_id = ?
    });

    $filename = $upload->{streaming} ?
      "$upload->{artist} - $upload->{title} [$upload->{quality}]"
      : $upload->{filename};

    my $body = encode_json {
      time => time,
      size => $upload->{size},
      filename => $filename,
    };

    my $sign = sub {
      my $row = shift;
      return () if grep {$_->{id} == $row->{id}} @servers;
      my $sig = hmac_sha1_hex $body, $row->{token};
      my $token = encode_base64 join ":", $sig, $body;
      return +{
        id    => $row->{id},
        name  => $row->{name},
        url   => $row->{url},
        token => $token,
      };
    };

    $all->execute;
    while (my $row = $all->fetchrow_hashref) {
      push @servers, $sign->($row);
    }

    $tags->execute($upload_id);
    while (my $row = $tags->fetchrow_hashref) {
      push @servers, $sign->($row);
    }

    $users->execute($upload->{user_id});
    while (my $row = $users->fetchrow_hashref) {
      push @servers, $sign->($row);
    }
    api_response {servers => \@servers};
  });
};

post '/my/servers' => sub {
  my ($self, $req) = @_;
  my $p = $req->parameters;

  die "only for users" unless $req->type eq "user";
  for (qw{name url}) {
    die "$_ is required" unless
      defined $p->{$_} and $p->{$_} ne "";
  }

  my $token =  sha1_hex(rand(time));

  $self->db->run(sub {
    $_->do(q{
      INSERT INTO server (name, token, url, last_sync, user_id)
        VALUES (?,?,?,?,?)
    }, undef, $p->{name}, $token, $p->{url}, time, $req->id);
  });

  api_response_ok;
};

del qr{/my/server/(\d+)} => sub {
  my ($self, $req, $server_id) = @_;

  die "only for users" unless $req->type eq "user";

  $self->db->txn(sub {
    $_->do(q{
      DELETE FROM server
      WHERE id = ?
        AND user_id = ?
    }, undef, $server_id, $req->id);
    $_->do(q{
      DELETE FROM tag_subscription
      WHERE subscriber_id = ?
        AND type = "server"
    }, undef, $server_id);
    $_->do(q{
      DELETE FROM user_subscription
      WHERE subscriber_id = ?
        AND type = "server"
    }, undef, $server_id);
  });

  api_response_ok;
};

del qr{/my/server/(\d+)/token} => sub {
  my ($self, $req, $server_id) = @_;

  my $token = sha1_hex(rand(time));
  $self->db->run(sub {
    $_->do(q{
      UPDATE server SET token = ? WHERE id = ? AND user_id = ?
    }, undef, $token, $server_id, $req->id);
  });
  api_response { success => "ok", token => $token }; 
};

post qr{/my/server/(\d+)} => sub {
  my ($self, $req, $server_id) = @_;
  my $p = $req->parameters;
  my %fields;

  for (qw{name url}) {
    if (defined $p->{$_} and $p->{$_} ne "") {
      $fields{$_} = $p->{$_};
    }
  }

  if (defined $p->{everything}) {
    $fields{everything} = $p->{everything} eq "on" ? 1 : 0;
  }

  $self->db->run(sub {
    for my $col (keys %fields) {
      my $name = $_->quote_identifier($col);
      $_->do(qq{
        UPDATE server SET $name=? WHERE id=? AND user_id=?
      }, undef, $fields{$col}, $server_id, $req->id);
    }
  });

  api_response_ok;
};

get '/my/upload/servers' => sub {
  my ($self, $req) = @_;

  my @tags = map {s/^\s+//; s/\s+$//; $_} $req->parameters->get_all('tags[]');
  my $tag_placeholders = join ",", map {"?"} 0 .. $#tags;

  my $query = qq{
    SELECT s.id, s.name, s.token, s.url
    FROM server AS s
    WHERE
      s.everything = 1
      OR
      s.id IN (
        SELECT us.subscriber_id
        FROM user_subscription AS us
        WHERE us.user_id = ?
          AND us.type = "server"
      )
      OR
      s.id IN (
        SELECT ts.subscriber_id
        FROM tag_subscription AS ts
          INNER JOIN tag AS t
            ON t.id = ts.tag_id
        WHERE ts.type = "server"
          AND t.slug IN ($tag_placeholders)
      )
  };

  my $sth = $self->db->run(sub {
    my $sth = $_->prepare($query);
    $sth->execute($req->id, @tags);
    $sth;
  });

  my @servers;
  while (my $row = $sth->fetchrow_hashref) {
    my $body  = encode_json {time => $time}; 
    my $sig   = hmac_sha1_hex $body, $row->{token};
    my $token = encode_base64 join ":", $sig, $body;
    push @servers, {
      id    => $row->{id},
      name  => $row->{name},
      url   => $row->{url},
      token => $token,
    };
  }
  api_response {servers => \@servers};
};

get '/my/downloads' => sub {
  my ($self, $req) = @_;

  my $query = q{
    SELECT u.*
    FROM upload AS u
    WHERE
      u.user_id IN (
        SELECT us.user_id
        FROM user_subscription AS us
        WHERE us.subscriber_id = ?
          AND us.type = ?
      )
      OR
      u.id IN (
        SELECT ut.upload_id
        FROM upload_tag AS ut
          INNER JOIN tag_subscription AS ts
            ON ts.tag_id = ut.tag_id
        WHERE ts.subscriber_id = ?
          AND ts.type = ?
        GROUP BY ut.upload_id
      )
    ORDER BY id DESC
    LIMIT ?, ?
  };

  my $sth = $self->db->run(sub {
    my @bind = ($req->id, $req->type, $req->id, $req->type);

    # check if server subscribers to everything
    # if so, modify query and bind vars
    if ($req->type eq "server") {
      my ($everything) = $_->selectrow_array(q{
        SELECT everything FROM server WHERE id = ?
      }, undef, $req->id);
      if ($everything) {
        $query = q{SELECT * FROM upload ORDER BY id DESC LIMIT ?, ?};
        @bind = ();
      }
    }

    my $sth = $_->prepare($query);
    $sth->execute(@bind, limit $req);
    $sth;
  });

  api_response {downloads => $sth->fetchall_arrayref({})};
};

post '/my/tags' => sub {
  my ($self, $req) = @_;

  die "tag is required" unless defined $req->parameters->{tag};
  my $tag = $req->parameters->{tag};
  $tag =~ s/^\s+//;
  $tag =~ s/\s+$//;

  $self->db->txn(sub {
    $_->do(q{
      INSERT OR IGNORE INTO tag (slug) VALUES (?)
    }, undef, $tag);

    $_->do(q{
      INSERT OR IGNORE INTO tag_subscription (subscriber_id, type, tag_id)
        SELECT ?,?,id
        FROM tag
        WHERE slug = ?
    }, undef, $req->id, $req->type, $tag);
  });

  api_response_ok;
};

post '/my/users' => sub {
  my ($self, $req) = @_;

  die "user is required" unless defined $req->parameters->{user};
  my $user_id = $self->auth->find_userid($req->parameters->{user});

  die "invalid username" unless $user_id;

  $self->db->run(sub {
    $_->do(q{
      INSERT OR IGNORE INTO user_subscription (subscriber_id, type, user_id)
        VALUES (?,?,?)
    }, undef, $req->id, $req->type, $user_id);
  });

  api_response_ok;
};

del qr{/my/tag/([^/]+)} => sub {
  my ($self, $req, $slug) = @_;

  $self->db->run(sub {
    my ($tag_id) = $_->selectrow_array(q{
      SELECT id FROM tag WHERE slug = ?
    }, undef, $slug);

    die "unknown tag" unless defined $tag_id;

    $_->do(q{
      DELETE FROM tag_subscription
      WHERE tag_id = ?
        AND subscriber_id = ?
        AND type = ?
    }, undef, $tag_id, $req->id , $req->type);
  });

  api_response_ok;
};

del qr{/my/user/(\d+)} => sub {
  my ($self, $req, $sub_id) = @_;

  $self->db->run(sub {
    $_->do(q{
      DELETE FROM user_subscription
      WHERE user_id = ?
        AND subscriber_id = ?
        AND type = ?
    }, undef, $sub_id, $req->id, $req->type);
  });

  api_response_ok;
};

post qr{/upload/(\d+)/fetches} => sub {
  my ($self, $req, $upload_id) = @_;
  die "users only" unless $req->type eq "user";
  die "server id is required" unless defined $req->parameters->{server};

  my $server_id = $req->parameters->{server};

  $self->db->run(sub {
    $_->do(q{INSERT INTO upload_fetch (upload_id, server_id, user_id, timestamp)
      VALUES(?,?,?,?)
    }, undef, $upload_id, $server_id, $req->id, time);
  });

  api_response_ok;
};

1;

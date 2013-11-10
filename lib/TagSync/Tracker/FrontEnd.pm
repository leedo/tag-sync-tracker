package TagSync::Tracker::FrontEnd;

use parent "Plack::Component";

use Plack::Util::Accessor qw{db auth};
use TagSync::Web;
use TagSync::Tracker::Request::User;
use Plack::Request;
use Text::Xslate;
use URI::Escape;
use MIME::Base64;
use Encode;
use JSON;

sub error {
  my ($self, $error) = @_;
  $self->render("error", {error => $error});
}

sub prepare_req {
  my ($self, $env) = @_;

  my $req = TagSync::Tracker::Request::User->new($env);
  my $user_id = $self->auth->auth_request($req);
  $req->set_id($user_id);

  die "unable to authorize request" unless defined $req->id;

  $req;
}

sub template {
  my $self = shift;
  $self->{template} ||= do {
    Text::Xslate->new(
      path => ["share/templates"],
      function => {
        megabytes => sub {
          my $bytes = shift;
          return int($bytes / 1000 / 1000);
        },
      }
    );
  };
}

sub limit {
  my ($req) = @_;
  my $page = $req->parameters->{page} || 1;
  ($page - 1) * 50, 50;
}

sub render {
  my ($self, $page, $vars) = @_;
  my $html = encode "utf8", $self->template->render("$page.tx", $vars);
  return [
    200,
    ["Content-Type", "text/html; charset=utf-8"],
    [$html],
  ];
}

get "/upload" => sub {
  my ($self, $req) = @_;
  my ($key) = $req->parameters->keys;

  # step 1
  return $self->render('upload-begin') unless $key;

  # step 2
  my $data = decode_json decode_base64 uri_unescape $key;
  
  # check if this hash already exists...
  my $sth = $self->db->run(sub {
    my $sth = $_->prepare(q{SELECT * FROM upload WHERE hash = ?});
    $sth->execute($data->{hash});
    $sth;
  });

  if (my $existing = $sth->fetchrow_hashref) {
    return $self->render('upload-exists', {
      upload => $existing,
      data   => $data,
    });
  }

  $self->render('upload-complete', $data);
};

get "/my-servers" => sub {
  my ($self, $req) = @_;
  my @servers;

  $self->db->run(sub {
    my $sth = $_->prepare(q{SELECT * FROM server WHERE user_id = ?});
    my $tags = $_->prepare(q{
      SELECT t.slug, t.id
      FROM tag_subscription AS ts
      INNER JOIN tag AS t
        ON t.id = ts.tag_id
      WHERE type = "server"
        AND subscriber_id = ?
    });
    my $users = $_->prepare(q{
      SELECT us.user_id
      FROM user_subscription AS us
      WHERE type="server"
        AND subscriber_id = ?
    });
    $sth->execute($req->id);
    while (my $server = $sth->fetchrow_hashref) {
      $tags->execute($server->{id});
      $users->execute($server->{id});
      $server->{tags} = $tags->fetchall_arrayref({});
      my @users = map {$_->{user_id}} @{$users->fetchall_arrayref({})};
      $server->{users} = $self->auth->identify_users(@users);
      push @servers, $server;
    }
  });

  $self->render('my-servers', {servers => \@servers});
};

get qr{/upload/(\d+)(/embed)?} => sub {
  my ($self, $req, $upload_id, $embed) = @_;

  my $upload = $self->db->run(sub {
    my $tags = $_->prepare(q{
      SELECT t.slug, t.id, ut.user_id
      FROM upload_tag AS ut
      INNER JOIN tag AS t
        ON t.id = ut.tag_id
      WHERE ut.upload_id = ?
    });
    my $fetches = $_->prepare(q{
      SELECT COUNT(*)
      FROM upload_fetch
      WHERE upload_id = ?
    });

    my $sth = $_->prepare(q{SELECT * FROM upload WHERE id = ?});
    $sth->execute($upload_id);
    my $upload = $sth->fetchrow_hashref;

    die "invalid upload id" unless defined $upload;

    $tags->execute($upload_id);
    $fetches->execute($upload_id);
    $upload->{tags} = $tags->fetchall_arrayref({});
    $upload->{user} = $self->auth->identify_users($upload->{user_id})->[0];
    ($upload->{fetches}) = $fetches->fetchrow_array;
    $upload;
  });

  $self->render('upload', {
    upload => $upload,
    user_id => $req->id,
    embed => defined $embed
  });
};

get "/uploads" => sub {
  my ($self, $req) = @_;
  my @uploads;

  $self->db->run(sub {
    my $tags = $_->prepare(q{
      SELECT t.slug, t.id
      FROM upload_tag AS ut
      INNER JOIN tag AS t
        ON t.id = ut.tag_id
      WHERE ut.upload_id = ?
    });
    my $sth = $_->prepare(q{SELECT * FROM upload ORDER BY id DESC LIMIT ?, ?});
    $sth->execute(limit $req);
    while (my $upload = $sth->fetchrow_hashref) {
      $tags->execute($upload->{id});
      $upload->{tags} = $tags->fetchall_arrayref({});
      $upload->{user} = $self->auth->identify_users($upload->{user_id})->[0];
      push @uploads, $upload;
    }
  });

  $self->render("uploads", {uploads => \@uploads, title => "All uploads"});
};

get qr{/user/(\d+)} => sub {
  my ($self, $req, $user_id) = @_;
  my (@uploads, @downloads, $users, $tags, $following, $followers);
  $user = $self->auth->identify_users($user_id)->[0];

  $self->db->run(sub {
    my $tag_sth = $_->prepare(q{
      SELECT t.slug, t.id
      FROM upload_tag AS ut
      INNER JOIN tag AS t
        ON t.id = ut.tag_id
      WHERE ut.upload_id = ?
    });
    my $upload_sth = $_->prepare(q{
      SELECT u.*
      FROM upload AS u
      WHERE u.user_id = ?
      ORDER BY u.id DESC
      LIMIT ?,?
    });
    my $download_sth = $_->prepare(q{
      SELECT u.*,uf.timestamp
      FROM upload_fetch AS uf
      INNER JOIN upload as u
        ON u.id = uf.upload_id
      WHERE uf.user_id = ?
      ORDER BY uf.timestamp DESC
      LIMIT ?,?
    });
    $upload_sth->execute($user_id, limit $req);
    while (my $upload = $upload_sth->fetchrow_hashref) {
      $tag_sth->execute($upload->{id});
      $upload->{tags} = $tag_sth->fetchall_arrayref({});
      $upload->{user} = $user;
      push @uploads, $upload;
    }
    $download_sth->execute($user_id, limit $req);
    while (my $download = $download_sth->fetchrow_hashref) {
      $tag_sth->execute($download->{id});
      $download->{tags} = $tag_sth->fetchall_arrayref({});
      $download->{user} = $self->auth->identify_users($download->{user_id})->[0];
      $download->{upload_date} = $download->{timestamp};
      push @downloads, $download;
    }
    ($following) = $_->selectrow_array(q{
      SELECT 1 
      FROM user_subscription
      WHERE subscriber_id = ?
      AND type = "user"
      AND user_id = ?
    }, undef, $req->id, $user_id);

    ($followers) = $_->selectrow_array(q{
      SELECT COUNT(*)
      FROM user_subscription
      WHERE user_id = ?
    }, undef, $user_id);

    $tags = $_->selectall_arrayref(q{
      SELECT t.*
      FROM tag_subscription AS ts
      INNER JOIN tag AS t
        ON t.id = ts.tag_id
      WHERE ts.type = "user"
        AND ts.subscriber_id = ?
    }, {Slice => {}}, $user_id);
    
    my $user_ids = $_->selectall_arrayref(q{
      SELECT us.user_id
      FROM user_subscription AS us
      WHERE us.type = "user"
        AND us.subscriber_id = ?
    }, undef, $user_id);
    $users = $self->auth->identify_users(map {$_->[0]} @$user_ids);
  });

  $self->render("user", {
    uploads => \@uploads,
    downloads => \@downloads,
    following => $following,
    followers => ($followers || 0),
    tags => $tags,
    users => $users,
    user => $user,
  });
};

get qr{/tag/([^/]+)} => sub {
  my ($self, $req, $slug) = @_;
  my (@uploads, $followers, $following);

  $self->db->run(sub {
    my $tags = $_->prepare(q{
      SELECT t.slug, t.id
      FROM upload_tag AS ut
      INNER JOIN tag AS t
        ON t.id = ut.tag_id
      WHERE ut.upload_id = ?
    });
    my $sth = $_->prepare(q{
      SELECT u.*
      FROM upload_tag AS ut
      INNER JOIN tag AS t
        ON t.id = ut.tag_id
      INNER JOIN upload AS u
        ON u.id = ut.upload_id
      WHERE t.slug = ?
      ORDER BY ut.upload_id DESC
      LIMIT ?,?
    });
    $sth->execute($slug, limit $req);
    while (my $upload = $sth->fetchrow_hashref) {
      $tags->execute($upload->{id});
      $upload->{tags} = $tags->fetchall_arrayref({});
      $upload->{user} = $self->auth->identify_users($upload->{user_id})->[0];
      push @uploads, $upload;
    }

    ($following) = $_->selectrow_array(q{
      SELECT 1 
      FROM tag_subscription AS ts
      INNER JOIN tag AS t
        ON t.id = ts.tag_id
      WHERE ts.subscriber_id = ?
      AND ts.type = "user"
      AND t.slug = ?
    }, undef, $req->id, $slug);

    ($followers) = $_->selectrow_array(q{
      SELECT COUNT(*)
      FROM tag_subscription AS ts
      INNER JOIN tag AS t
        ON t.id = ts.tag_id
      WHERE t.slug = ?
    }, undef, $slug);
  });

  $self->render("tag", {
    uploads => \@uploads,
    following => $following,
    followers => ($followers || 0),
    tag => $slug,
  });
};

get "/servers" => sub {
  my ($self, $req) = @_;
  my @servers;

  $self->db->run(sub {
    my $sth = $_->prepare("SELECT * FROM server");
    my $tags = $_->prepare(q{
      SELECT t.slug, t.id
      FROM tag_subscription AS ts
      INNER JOIN tag AS t
        ON t.id = ts.tag_id
      WHERE type = "server"
        AND subscriber_id = ?
    });
    my $users = $_->prepare(q{
      SELECT us.user_id
      FROM user_subscription AS us
      WHERE type="server"
        AND subscriber_id = ?
    });
    $sth->execute;
    while (my $server = $sth->fetchrow_hashref) {
      $tags->execute($server->{id});
      $users->execute($server->{id});
      $server->{admin} = $self->auth->identify_users($server->{user_id})->[0];
      $server->{tags} = $tags->fetchall_arrayref({});
      my @users = map {$_->{user_id}} @{$users->fetchall_arrayref({})};
      $server->{users} = $self->auth->identify_users(@users);
      push @servers, $server;
    }
  });

  $self->render('server-list', {servers => \@servers});
};

get "/my-subscriptions" => sub {
  my ($self, $req) = @_;
  my @users, @tags;
  $self->db->run(sub {
    my $tags = $_->prepare(q{
      SELECT t.id, t.slug
      FROM tag_subscription AS ts
      INNER JOIN tag AS t
        ON t.id = ts.tag_id
      WHERE ts.subscriber_id = ?
        AND ts.type = "user"
    });
    my $users = $_->prepare(q{
      SELECT us.user_id
      FROM user_subscription AS us
      WHERE us.subscriber_id = ?
        AND us.type = "user"
    });
    $tags->execute($req->id);
    $users->execute($req->id);
    my @user_ids = map {$_->[0]} @{$users->fetchall_arrayref};
    @users = @{$self->auth->identify_users(@user_ids)};
    @tags = @{$tags->fetchall_arrayref({})};
  });
  $self->render("my-subscriptions", {
    users => \@users,
    tags => \@tags,
    uploads => $self->my_uploads($req),
  });
};

get "/tags.json" => sub {
  my ($self, $req) = @_;
  my @tags;
  $self->db->run(sub {
    my $sth = $_->prepare(q{SELECT id,slug FROM tag});
    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
      push @tags, $row->{slug};
    }
  });
  api_response \@tags;
};

get "/users.json" => sub {
  my ($self, $req) = @_;
  die "query is required" unless defined $req->parameters->{q};
  my @users = $self->auth->search_users($req->parameters->{q});
  api_response \@users;
};

get "" => sub {
  my ($self, $req) = @_;
  [301, ["Location", "/tracker/uploads"], ["moved"]];
};

sub my_uploads {
  my ($self, $req) = @_;
  my @uploads;

  my $query = q{
    SELECT u.*
    FROM upload AS u
    WHERE
      u.user_id IN (
        SELECT us.user_id
        FROM user_subscription AS us
        WHERE us.subscriber_id = ?
          AND us.type = "user"
      )
      OR
      u.id IN (
        SELECT ut.upload_id
        FROM upload_tag AS ut
          INNER JOIN tag_subscription AS ts
            ON ts.tag_id = ut.tag_id
        WHERE ts.subscriber_id = ?
          AND ts.type = "user"
        GROUP BY ut.upload_id
      )
    ORDER BY u.id DESC
    LIMIT ?, ?
  };


  $self->db->run(sub {
    my $sth = $_->prepare($query);
    my $tags = $_->prepare(q{
      SELECT t.slug, t.id
      FROM upload_tag AS ut
      INNER JOIN tag AS t
        ON t.id = ut.tag_id
      WHERE ut.upload_id = ?
    });
    $sth->execute($req->id, $req->id, limit $req);
    while (my $upload = $sth->fetchrow_hashref) {
      $tags->execute($upload->{id});
      $upload->{tags} = $tags->fetchall_arrayref({});
      $upload->{user} = $self->auth->identify_users($upload->{user_id})->[0];
      push @uploads, $upload;
    }
  });

  return \@uploads;
}

1;

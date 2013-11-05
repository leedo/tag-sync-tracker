package TagSync::Auth::PunBB;

use PHP::Serialization qw{unserialize};
use URI::Escape;

sub new {
  my ($class, $db) = @_;
  bless {db => $db}, $class;
}

sub auth_request {
  my ($self, $req) = @_;

  my $cookie = $req->cookies->{punbb_cookie};
  die "Not logged in" unless defined $cookie;

  my $auth = unserialize uri_unescape $cookie;
  $auth->[0] =~ s/\+/ /g;
  $auth->[1] =~ s/\+/ /g;
  
  my $sth = $self->{db}->run(sub {
    my $sth = $_->prepare(q{SELECT id FROM users WHERE username = ? AND password = ?});
    $sth->execute(@$auth);
    $sth;
  });
  return $sth->fetchrow_array;
}

sub find_userid {
  my ($self, $name) = @_;
  my $sth = $self->{db}->run(sub {
    my $sth = $_->prepare(q{SELECT id FROM users WHERE username = ?});
    $sth->execute($name);
    $sth;
  });
  return $sth->fetchrow_array;
}

sub search_users {
  my ($self, $query) = @_;
  my $sth = $self->{db}->run(sub {
    my $sth = $_->prepare(q{SELECT username FROM users WHERE username LIKE ? LIMIT 10});
    $sth->execute($query . "%");
    $sth;
  });
  return map {$_->[0]} @{$sth->fetchall_arrayref};
}

sub identify_users {
  my ($self, @user_ids) = @_;
  my $sth = $self->{db}->run(sub {
    my $placeholders = join ",", "NULL", map {"?"} 0..$#user_ids;
    my $sth = $_->prepare(qq{SELECT id,username FROM users WHERE id IN ($placeholders)});
    $sth->execute(@user_ids);
    $sth;
  });
  return $sth->fetchall_arrayref({});
}

1;

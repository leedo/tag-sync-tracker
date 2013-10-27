package TagSync::Tracker::Request;

use parent qw{Plack::Request};

use TagSync::Tracker::Request::Server;
use TagSync::Tracker::Request::User;

sub factory {
  my $env = shift;

  if (my $token = $env->{HTTP_X_SERVER_AUTH}) {
    return TagSync::Tracker::Request::Server->new($env, $token);
  }
  else {
    return TagSync::Tracker::Request::User->new($env);
  }

  die "auth header missing";
}

sub set_id {
  my ($self, $id) = @_;
  $self->{id} = $id;
}
 
sub id { $_[0]->{id} }
sub type { die "required method" }

1;

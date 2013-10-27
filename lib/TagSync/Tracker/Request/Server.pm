package TagSync::Tracker::Request::Server;

use parent 'TagSync::Tracker::Request';

sub new {
  my ($class, $env, $token) = @_;
  my $self = $class->SUPER::new($env);
  $self->{token} = $token;
  $self;
}

sub token { $_[0]->{token} }
sub type { "server" }

1;

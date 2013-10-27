package TagSync::DB;

use DBIx::Connector;

sub new {
  my ($class, $dsn, $user, $pass) = @_;
  $user = "" unless defined $user;
  $pass = "" unless defined $pass;
  my $conn = DBIx::Connector->new($dsn, $user, $pass, {
    RaiseError => 1,
    AutoCommit => 1,
  });
  $conn->mode("fixup");
  return $conn;
}

1;

package TagSync::Auth::Test;

sub new {
  my ($class) = @_;
  bless {}, $class;
}

sub auth_request {
  return 1;
}

sub find_userid {
  return 1;
}

sub search_users {
  return ["test-user"];
}

sub identify_users {
  my ($self, @user_ids) = @_;
  return [map {+{id => 1, username => "test-user"}} 0..$#user_ids];
}

1;

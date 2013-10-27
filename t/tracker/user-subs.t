use Test::More;
use TagSync::Test::Tracker qw{test_tracker};
use HTTP::Request::Common qw{GET POST DELETE};
use JSON;
use Digest::SHA1 qw{sha1_hex};
use Data::Dump qw{pp};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(POST "/my/tags", [tag => "farts", user_id => 1]);
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(POST "/my/tags", [user => 2, user_id => 1]);
  is $res->code, 200;
  my $data = decode_json $res->content;
  is $data->{error}, "tag is required", "subscribe to tag with user";
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(POST "/my/users", [user => 2, user_id => 1]);
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(POST "/my/users", [tag => 2, user_id => 1]);
  is $res->code, 200;
  my $data = decode_json $res->content;
  is $data->{error}, "user is required", "subscribe to user with tag";
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/users?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is scalar @{$data->{users}}, 1;
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/tags?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is scalar @{$data->{tags}}, 1;
};

my %upload = (
  hash    => sha1_hex("farts"),
  sig     => sha1_hex("servertoken1" . "64" . sha1_hex("farts")),
  artist  => "Test Artist",
  title   => "Test Album",
  server  => 1,
  tags    => "farts",
  size    => 64,
  quality => "V0",
  info    => "megafarts",
);

test_tracker sub {
  my $cb = shift;

  my $res = $cb->(POST "/upload", [ %upload, user_id => 2 ]);
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  ok $data->{upload};
};

test_tracker sub {
  my $cb = shift;

  my $res = $cb->(GET "/my/downloads?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  is scalar @{$data->{downloads}}, 1;
};

test_tracker sub {
  my $cb = shift;
  my $res = $cb->(DELETE "/my/user/2?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;

  my $res2 = $cb->(GET "/my/users?user_id=1");
  is $res2->code, 200;
  my $data2 = decode_json $res2->content;
  is scalar @{$data2->{users}}, 0;
};

test_tracker sub {
  my $cb = shift;

  my $res = $cb->(GET "/my/downloads?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  is scalar @{$data->{downloads}}, 1;
};

test_tracker sub {
  my $cb = shift;
  my $res = $cb->(DELETE "/my/tag/farts?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;

  my $res2 = $cb->(GET "/my/tags?user_id=1");
  is $res2->code, 200;
  my $data2 = decode_json $res2->content;
  is scalar @{$data2->{tags}}, 0;
};


test_tracker sub {
  my $cb = shift;

  my $res = $cb->(GET "/my/downloads?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  is scalar @{$data->{downloads}}, 0;
};

done_testing();

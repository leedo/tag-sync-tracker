use Test::More;
use TagSync::Test::Tracker qw{test_tracker};
use HTTP::Request::Common;
use JSON;
use Data::Dump qw{pp};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(POST "/my/tags", [tag => "farts"], "X-Server-Auth" => "servertoken1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(POST "/my/tags", [user => 2], "X-Server-Auth" => "servertoken1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is $data->{error}, "tag is required", "subscribe to tag with user";
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(POST "/my/users", [user => 2], "X-Server-Auth" => "servertoken1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  warn $data->{error} if defined $data->{error};
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(POST "/my/users", [tag => 2], "X-Server-Auth" => "servertoken1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is $data->{error}, "user is required", "subscribe to user with tag";
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/users", "X-Server-Auth" => "servertoken1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is scalar @{$data->{users}}, 1;
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/user/2/servers", "X-Server-Auth" => "servertoken1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is scalar @{$data->{servers}}, 1;
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/tags", "X-Server-Auth" => "servertoken1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is scalar @{$data->{tags}}, 1;
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/tag/farts/servers", "X-Server-Auth" => "servertoken1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is scalar @{$data->{servers}}, 1;
};

done_testing();

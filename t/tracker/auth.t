use Test::More;
use TagSync::Test::Tracker qw{test_tracker};
use HTTP::Request::Common;
use JSON;

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/tags");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is $data->{error}, "unable to authorize request", "user request with failed auth";
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/tags?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  warn $data->{error} if defined $data->{error};
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/tags", "X-Server-Auth" => "brokentoken");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is $data->{error}, "unable to authorize request", "server request with broken token";
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/tags", "X-Server-Auth" => "servertoken1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  warn $data->{error} if defined $data->{error};
};


done_testing();

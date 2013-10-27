use Test::More;
use TagSync::Test::Tracker qw{test_tracker};
use HTTP::Request::Common;
use JSON;
use Data::Dump qw{pp};

test_tracker sub {
  my $cb  = shift;
  for my $tag (0 .. 75) {
    $cb->(POST "/my/tags?user_id=1", [tag => "tag-$tag"]);
  }
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/tags?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is scalar @{$data->{tags}}, 50;
};

test_tracker sub {
  my $cb  = shift;
  my $res = $cb->(GET "/my/tags?user_id=1&page=2");
  is $res->code, 200;
  my $data = decode_json $res->content;
  is scalar @{$data->{tags}}, 26;
};

done_testing();

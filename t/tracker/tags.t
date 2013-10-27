use Test::More;
use TagSync::Test::Tracker qw{test_tracker};
use HTTP::Request::Common qw{GET POST DELETE};
use JSON;
use Digest::SHA1 qw{sha1_hex};
use Data::Dump qw{pp};

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
  
  my $res = $cb->(POST "/upload/1/tags", [tag => "megafarts", user_id => 1]);
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
};

test_tracker sub {
  my $cb = shift;
  
  my $res = $cb->(GET "/upload/1/tags?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  is scalar @{$data->{tags}}, 2;
};

test_tracker sub {
  my $cb = shift;
  
  my $res = $cb->(DELETE "/upload/1/tag/megafarts?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
};

test_tracker sub {
  my $cb = shift;
  
  my $res = $cb->(GET "/upload/1/tags?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  is scalar @{$data->{tags}}, 1;
};


done_testing();

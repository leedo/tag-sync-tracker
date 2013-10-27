use Test::More;
use TagSync::Test::Tracker qw{test_tracker};
use HTTP::Request::Common;
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

  my $res2 = $cb->(GET "/upload/$data->{upload}?user_id=1");
  is $res2->code, 200;
  my $data2 = decode_json $res2->content;
  ok defined $data2->{upload};
  is $data2->{upload}{id}, $data->{upload};
  is $data2->{upload}{user_id}, 2;

  for (qw{hash artist title size quality info}) {
    is $upload{$_}, $data2->{upload}{$_};
  }
};

test_tracker sub {
  my $cb = shift;

  my $res = $cb->(GET "/tag/farts/uploads?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  is scalar @{$data->{uploads}}, 1;
  is $data->{uploads}[0]{user_id}, 2;

  for (qw{hash artist title size quality info}) {
    is $upload{$_}, $data->{uploads}[0]{$_};
  }
};

test_tracker sub {
  my $cb = shift;

  my $res = $cb->(GET "/user/2/uploads?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  is scalar @{$data->{uploads}}, 1;
  is $data->{uploads}[0]{user_id}, 2;

  for (qw{hash artist title size quality info}) {
    is $upload{$_}, $data->{uploads}[0]{$_};
  }
};

test_tracker sub {
  my $cb = shift;

  my $res = $cb->(GET "/uploads?user_id=1");
  is $res->code, 200;
  my $data = decode_json $res->content;
  ok not defined $data->{error};
  is scalar @{$data->{uploads}}, 1;
  is $data->{uploads}[0]{user_id}, 2;

  for (qw{hash artist title size quality info}) {
    is $upload{$_}, $data->{uploads}[0]{$_};
  }
};

done_testing();

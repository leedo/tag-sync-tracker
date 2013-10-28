use Plack::Builder;
use TagSync::Tracker::API;
use TagSync::Tracker::FrontEnd;
use TagSync::DB;

my $config = do {
  my $file = $ENV{TT_CONFIG} || "conf/tracker.pl";
  do $file;
};

builder {
  enable "Plack::Middleware::Static",
    path => sub {s!^/assets/!!}, root => "public";
  mount "/api" => TagSync::Tracker::API->new(
    db   => $config->{db},
    auth => $config->{auth},
  )->to_app;
  mount "/tracker" => TagSync::Tracker::FrontEnd->new(
    db   => $config->{db},
    auth => $config->{auth},
  )->to_app;
}

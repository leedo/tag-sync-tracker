use Plack::Builder;
use TagSync::Tracker::API;
use TagSync::Tracker::FrontEnd;
use TagSync::DB;
use TagSync::Auth::PunBB;

my $db = TagSync::DB->new("dbi:SQLite:dbname=tracker.db");
my $auth = TagSync::Auth::PunBB->new(
  TagSync::DB->new("dbi:mysql:dbname=punbb", "punbb", "punbb")
);

builder {
  enable "Plack::Middleware::Static",
    path => sub {s!^/assets/!!}, root => "public";
  mount "/api" => TagSync::Tracker::API->new(
    db => $db,
    auth => $auth,
  )->to_app;
  mount "/tracker" => TagSync::Tracker::FrontEnd->new(
    db => $db,
    auth => $auth,
    url => "http://localhost:5000",
  )->to_app;
}

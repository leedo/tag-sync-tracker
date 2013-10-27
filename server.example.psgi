use TagSync::Server::Sync;
use Plack::Builder;

builder {
  enable "CrossOrigin",
    origins => "http://localhost:5000",
    headers => '*',
    methods => ["GET", "POST"];

  TagSync::Server::Sync->new(
    id        => 1,
    token     => 'fc6814acda09c399824881e7cf767172f599a661',
    data_root => './data',
    tracker   => 'localhost:5000',
  )->to_app;
};
